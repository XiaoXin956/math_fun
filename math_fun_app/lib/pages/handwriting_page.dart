import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/handwriting_pad.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

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
  // 一次练习 = 一个批次，组内 5 题共享，家长按组批改、一次给分
  String _batchId = '';

  ApiClient get _client => Session.createClient();

  Future<void> _start() async {
    final rand = Random();
    setState(() {
      _playing = true;
      _answered = 0;
      _question = null;
      _feedback = '';
      // Web(DDC) 下 `1 << 32` 会被 JS 32 位位移截断成 0，导致 nextInt(0) 抛
      // RangeError；用 2^31-1 作为上界，跨平台都安全且随机性足够。
      _batchId = 'hw_${DateTime.now().microsecondsSinceEpoch}_'
          '${rand.nextInt(0x7FFFFFFF).toRadixString(16)}';
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
        'batch_id': _batchId,
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
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 可滚动内容：题号 / 题目 / 画板
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '第 ${_answered + 1} / 5 题',
                              style: const TextStyle(
                                  fontSize: 18, color: AppColors.inkSoft),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 22, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  _question?['expression'] as String? ?? '正在出题…',
                                  style: const TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('请在下方手写答案（字写大一些）',
                                style: TextStyle(
                                    fontSize: 15, color: AppColors.inkSoft)),
                            const SizedBox(height: 12),
                            HandwritingPad(key: _padKey),
                          ],
                        ),
                      ),
                    ),
                    // 底部固定操作栏：提交按钮始终可见
                    const SizedBox(height: 12),
                    if (_feedback.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _feedback,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success),
                        ),
                      ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed:
                              _busy ? null : () => _padKey.currentState?.clear(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('清空'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BrandButton(
                            _busy ? '提交中…' : '提交给家长批改',
                            icon: Icons.send_rounded,
                            loading: _busy,
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                      style: TextStyle(fontSize: 13, color: AppColors.inkFaint),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
