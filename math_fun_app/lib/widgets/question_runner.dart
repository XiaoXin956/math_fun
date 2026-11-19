import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../bloc/auth_cubit.dart';
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

  /// 闯关模式下点击返回/退出时调用，返回 true 表示确认退出。
  final Future<bool> Function()? onExitRequested;

  const QuestionRunner({
    super.key,
    required this.grade,
    required this.operation,
    required this.mode,
    this.totalQuestions,
    this.onComplete,
    this.onExitRequested,
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
  bool _finished = false;

  Timer? _timer;
  int _secondsLeft = 0;
  final _startTime = DateTime.now();

  // 自由练习 / 闯关：一次性下发全部题目+答案，本地判分，最后批量上报
  List<Map<String, dynamic>> _batch = [];
  int _batchIndex = 0;
  final List<Map<String, dynamic>> _batchResults = [];
  Map<String, dynamic>? _practicePoints;
  bool get _isBatch =>
      widget.mode == 'practice' || widget.mode == 'challenge';

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'timed') {
      _secondsLeft = _initialSeconds();
      _startTimer();
    }
    if (_isBatch) {
      _loadBatch();
    } else {
      _loadQuestion();
    }
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
        'type': 'math',
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

  /// 自由练习：一次请求拉取全部题目（含答案），答题过程无需再访问网络。
  Future<void> _loadBatch() async {
    setState(() {
      _question = null;
      _feedback = '';
    });
    try {
      final res = await _client.post('/api/practice/questions', {
        'grade': widget.grade,
        'operation': widget.operation,
        'count': widget.totalQuestions ?? 10,
      });
      final questions = res['questions'] as List;
      if (!mounted) return;
      setState(() {
        _batch = questions.cast<Map<String, dynamic>>();
        _batchIndex = 0;
        _question = _batch.isEmpty ? null : _batch.first;
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
    if (_isBatch) {
      _submitLocal(answer);
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

  /// 自由练习：用已下发的答案本地即时判分，无网络等待；全部答完再批量上报。
  void _submitLocal(int answer) {
    if (_question == null) return;
    final correctAnswer = _question!['answer'] as int;
    final correct = answer == correctAnswer;

    _batchResults.add({
      'question_id': _question!['id'],
      'user_answer': answer,
      'duration_ms': DateTime.now().difference(_startTime).inMilliseconds,
    });

    setState(() {
      _feedbackCorrect = correct;
      _feedback = correct
          ? '太棒了，答对了！🎉'
          : '没关系，正确答案是 $correctAnswer，再试一次！';
      _answered++;
      if (correct) _correctCount++;
    });

    if (_answered >= _batch.length) {
      _finishBatch();
      return;
    }
    _batchIndex++;
    _controller.clear();
    setState(() => _question = _batch[_batchIndex]);
    _focus.requestFocus();
  }

  /// 自由练习全部答完：一次性把本地判分结果上报后端入库，再弹结算窗。
  Future<void> _finishBatch() async {
    setState(() => _busy = true);
    try {
      final res = await _client.post('/api/practice/results', {
        'grade': widget.grade,
        'mode': widget.mode,
        'results': _batchResults,
      });
      // 仅自由练习有 practice 积分；闯关积分由 completeChallenge 负责
      final p = res['points'];
      if (p is Map<String, dynamic>) {
        _practicePoints = p;
        if ((p['changed'] as int? ?? 0) != 0 && mounted) {
          context.read<AuthCubit>().refresh();
        }
      }
    } catch (e) {
      // 上报失败不阻塞结算展示，但要提示用户
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('成绩上报失败，本次记录可能未保存')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    _finish();
  }

  void _finish() {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    final summary = <String, dynamic>{
      'mode': widget.mode,
      'grade': widget.grade,
      'correct': _correctCount,
      'total': _answered,
      'seconds': DateTime.now().difference(_startTime).inSeconds,
      if (_practicePoints != null) 'points': _practicePoints,
    };
    if (widget.onComplete != null) {
      widget.onComplete!(summary);
    } else {
      // 自由练习等无外部回调的模式：弹结算窗，用户确认后自动关闭答题页返回上一级。
      // （此前只关了弹窗，答题页停留在最后一题，用户需手动按返回键）
      showSummaryDialog(context, summary).then((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    if (e is ApiException && e.status == 401) {
      Session.clear().then((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
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

  /// 请求退出：闯关模式中途退出需要先确认（扣 5 分）。
  Future<void> _requestExit() async {
    if (widget.mode == 'challenge' && !_finished &&
        widget.onExitRequested != null) {
      final ok = await widget.onExitRequested!();
      if (ok && mounted) {
        Navigator.of(context).pop();
      }
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalQuestions;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == 'timed' ? '限时挑战 ⏰' : '答题中 🎯'),
      ),
      body: SafeArea(
        child: PopScope(
          canPop: !(widget.mode == 'challenge' &&
              !_finished &&
              widget.onExitRequested != null),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _requestExit();
          },
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
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          SizedBox(height: 12),
                          Text('正在出题…',
                              style: TextStyle(
                                  fontSize: 18, color: Color(0xFF8A5A4A))),
                        ],
                      )
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
                // 自由练习最后一题提交后进入批量上报，按钮切换为加载框
                child: _isBatch && _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        _question == null ? '等待出题…' : '提交答案',
                        style: const TextStyle(fontSize: 20),
                      ),
              ),
              if (widget.mode == 'timed')
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: const Text('提前结束'),
                ),
              if (widget.mode == 'challenge')
                TextButton(
                  onPressed: _busy ? null : _requestExit,
                  child: const Text('退出闯关（扣5分）'),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
