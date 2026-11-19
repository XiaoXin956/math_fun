import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../pages/login_page.dart';
import '../services/session.dart';
import '../widgets/common.dart';

/// 答题运行组件：出题 → 输入答案 → 判分反馈 → 下一题。
///
/// - [mode] 为 'timed' 时显示倒计时，时间到自动结算；
/// - [totalQuestions] 为空时不限题数（配合 timed 使用）。
class QuestionRunner extends StatefulWidget {
  final int grade;
  final String operation;
  final String mode; // practice / challenge / timed
  final int? totalQuestions;
  final void Function(Map<String, dynamic> summary)? onComplete;

  const QuestionRunner({
    super.key,
    required this.grade,
    required this.operation,
    required this.mode,
    this.totalQuestions,
    this.onComplete,
  });

  @override
  State<QuestionRunner> createState() => _QuestionRunnerState();
}

class _QuestionRunnerState extends State<QuestionRunner> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  Map<String, dynamic>? _question;
  String _feedback = '';
  bool _feedbackCorrect = false;
  bool _busy = false;

  int _answered = 0;
  int _correctCount = 0;

  Timer? _timer;
  int _secondsLeft = 0;
  final _startTime = DateTime.now();

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'timed') {
      _secondsLeft = _initialSeconds();
      _startTimer();
    }
    _loadQuestion();
  }

  int _initialSeconds() => timedDurationSeconds;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _timer = null;
        _finish();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _question = null;
      _feedback = '';
    });
    try {
      final res = await _client.post('/api/questions', {
        'grade': widget.grade,
        'operation': widget.operation,
        'count': 1,
      });
      final questions = res['questions'] as List;
      if (!mounted) return;
      setState(() {
        _question = questions.first as Map<String, dynamic>;
        _feedback = '';
      });
      _focus.requestFocus();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final answer = int.tryParse(text);
    if (_busy) return;
    if (answer == null) {
      setState(() {
        _feedback = '请输入一个整数答案哦～';
        _feedbackCorrect = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _feedback = '判分中…';
    });
    try {
      final res = await _client.post('/api/results', {
        'question_id': _question!['id'],
        'user_answer': answer,
        'mode': widget.mode,
        'grade': widget.grade,
        'duration_ms': DateTime.now().difference(_startTime).inMilliseconds,
      });
      final correct = res['correct'] as bool;
      if (!mounted) return;
      setState(() {
        _feedbackCorrect = correct;
        _feedback = res['message'] as String;
        _answered++;
        if (correct) _correctCount++;
      });

      final isChallengeDone = widget.totalQuestions != null &&
          _answered >= widget.totalQuestions!;
      final isTimedDone = widget.mode == 'timed' && _secondsLeft <= 0;
      if (isChallengeDone || isTimedDone) {
        _finish();
        return;
      }
      _controller.clear();
      await _loadQuestion();
    } catch (e) {
      if (!mounted) return;
      setState(() => _feedback = '出错了，请重试');
      _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    final summary = <String, dynamic>{
      'mode': widget.mode,
      'grade': widget.grade,
      'correct': _correctCount,
      'total': _answered,
      'seconds': DateTime.now().difference(_startTime).inSeconds,
    };
    if (widget.onComplete != null) {
      widget.onComplete!(summary);
    } else {
      showSummaryDialog(context, summary);
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    if (e is ApiException && e.status == 401) {
      Session.clear().then((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e is ApiException ? e.message : '网络错误，请检查后端服务'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalQuestions;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == 'timed' ? '限时挑战 ⏰' : '答题中 🎯'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.mode == 'timed')
                Text(
                  '剩余 ${_secondsLeft} 秒',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE8842C),
                  ),
                )
              else if (total != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '第 ${_answered + 1} / $total 题',
                    style: const TextStyle(fontSize: 18, color: Color(0xFF8A5A4A)),
                  ),
                ),
              const SizedBox(height: 20),
              if (total != null && widget.mode != 'timed')
                SizedBox(
                  width: double.infinity,
                  height: 8,
                  child: LinearProgressIndicator(
                    value: _answered / total,
                    backgroundColor: const Color(0xFFFFE3DA),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7A59)),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _question == null
                    ? const Center(child: Text('正在出题…'))
                    : Text(
                        _question!['expression'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5A3E36),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: false, decimal: false),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFFFC9BC)),
                  ),
                  hintText: '输入答案',
                  hintStyle: const TextStyle(fontSize: 26),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              if (_feedback.isNotEmpty)
                Text(
                  _feedback,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _feedbackCorrect
                        ? const Color(0xFF2E9E5B)
                        : const Color(0xFFD9534F),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _question == null ? '等待出题…' : '提交答案',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              if (widget.mode == 'timed')
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('提前结束'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
