import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/handwriting_pad.dart';

/// 手写练习：出带书写区的算术题，孩子手写答案后提交给家长批改，
/// 批改通过加分、不通过扣分（分值由家长决定）。
class HandwritingPage extends StatefulWidget {
  static const routeName = '/handwriting';
  const HandwritingPage({super.key});

  @override
  State<HandwritingPage> createState() => _HandwritingPageState();
}

class _HandwritingPageState extends State<HandwritingPage> {
  final _padKey = GlobalKey<HandwritingPadState>();

  int _grade = 2;
  bool _playing = false;
  int _answered = 0;
  Map<String, dynamic>? _question;
  String _feedback = '';
  bool _busy = false;

  ApiClient get _client => Session.createClient();

  Future<void> _start() async {
    setState(() {
      _playing = true;
      _answered = 0;
      _question = null;
      _feedback = '';
    });
    await _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _question = null;
      _feedback = '';
    });
    try {
      final res = await _client.post('/api/questions', {
        'grade': _grade,
        'operation': 'mixed',
        'type': 'handwriting',
        'count': 1,
      });
      if (!mounted) return;
      setState(() {
        _question = (res['questions'] as List).first as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      _error(e is ApiException ? e.message : '出题失败，请重试');
    }
  }

  Future<void> _submit() async {
    if (_busy || _question == null) return;
    setState(() => _busy = true);
    final image = await _padKey.currentState?.capture();
    if (!mounted) return;
    if (image == null || image.isEmpty) {
      setState(() {
        _busy = false;
        _feedback = '没有获取到手写内容，请重新书写后再提交';
      });
      return;
    }
    try {
      await _client.post('/api/handwriting/submit', {
        'question_id': _question!['id'],
        'image': image,
      });
      if (!mounted) return;
      setState(() {
        _answered++;
        _feedback = '已提交，等待家长批改 ✅';
      });
      final total = 5;
      if (_answered >= total) {
        _finish();
        return;
      }
      _padKey.currentState?.clear();
      await _loadQuestion();
    } catch (e) {
      if (!mounted) return;
      setState(() => _feedback = '提交失败，请重试');
      _error(e is ApiException ? e.message : '提交失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish() {
    setState(() => _playing = false);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('本轮完成 ✍️', style: TextStyle(fontSize: 22)),
        content: const Text(
          '已提交 5 道手写题，家长批改通过后会获得或扣除相应积分，'
          '可在「积分记录」中查看。',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了')),
        ],
      ),
    );
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('✍️ 手写练习')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _playing
              ? SingleChildScrollView(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '第 ${_answered + 1} / 5 题',
                      style: const TextStyle(fontSize: 18, color: Color(0xFF8A5A4A)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          _question?['expression'] as String? ?? '正在出题…',
                          style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5A3E36)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('请在下方手写答案（字写大一些）',
                        style: TextStyle(fontSize: 15, color: Color(0xFF8A5A4A))),
                    const SizedBox(height: 12),
                    HandwritingPad(key: _padKey),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                            onPressed: _busy ? null : () => _padKey.currentState?.clear(),
                            child: const Text('清空重写')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(
                                _busy ? '提交中…' : '提交给家长批改')),
                      ],
                    ),
                    if (_feedback.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_feedback,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ]),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('选择年级',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GradeChips(
                        selected: _grade,
                        onChanged: (g) => setState(() => _grade = g)),
                    const Spacer(),
                    ElevatedButton(
                        onPressed: _start, child: const Text('开始手写练习（5 题）')),
                    const SizedBox(height: 12),
                    const Text(
                      '提交后由家长批改：批改正确加分，错误扣分，分值由家长决定（最多 10 分）',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB09A8E)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
