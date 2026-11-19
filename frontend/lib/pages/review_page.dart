import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';

/// 家长批改手写答案：查看孩子提交的手写图片，判断对错并决定加减分（0-10）。
class ReviewPage extends StatefulWidget {
  static const routeName = '/review';
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<HandwritingSubmission> _list = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _client.get('/api/handwriting/pending');
      if (!mounted) return;
      setState(() {
        _list = (res['submissions'] as List)
            .map((e) => HandwritingSubmission.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // 保持原状
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('✍️ 待批改')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('待批改手写答案',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _load, child: const Text('刷新')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _list.isEmpty
                        ? const Center(child: Text('没有待批改的提交 🎉'))
                        : ListView.separated(
                            itemCount: _list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _card(_list[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(HandwritingSubmission item) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Image.memory(
              _decodeImage(item.image),
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) =>
                  const Text('🖼️', style: TextStyle(fontSize: 24)),
            ),
          ),
        ),
        title: Text(item.childName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Text(item.expression,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _review(item),
      ),
    );
  }

  Uint8List _decodeImage(String base64) {
    final clean = base64.contains(',')
        ? base64.substring(base64.indexOf(',') + 1)
        : base64;
    return base64.decode(clean.replaceAll('\n', ''));
  }

  Future<void> _review(HandwritingSubmission item) async {
    bool correct = true;
    int points = 5;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('批改手写答案', style: TextStyle(fontSize: 20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Image.memory(
                            _decodeImage(item.image),
                            width: 200,
                            height: 130,
                            errorBuilder: (_, __, ___) =>
                                const Text('图片加载失败'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('题目',
                              style: TextStyle(fontSize: 14, color: Color(0xFF8A5A4A))),
                          const SizedBox(height: 4),
                          Text(item.expression,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          const Text('参考答案',
                              style: TextStyle(fontSize: 14, color: Color(0xFF8A5A4A))),
                          const SizedBox(height: 4),
                          Text(
                            '${item.answer}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('判断结果', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _choiceChip('答对了', true, (v) => setDialogState(() => correct = v)),
                    const SizedBox(width: 12),
                    _choiceChip('答错了', false, (v) => setDialogState(() => correct = v)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => setDialogState(() {
                          points = points == 0 ? 0 : points - 1;
                        })),
                    Text('积分 $points',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setDialogState(() {
                          points = points >= 10 ? 10 : points + 1;
                        })),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    '判断正确加 $points 分，判断错误扣 $points 分（0-10）',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB09A8E))),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final res = await _client.post('/api/handwriting/review', {
                      'submission_id': item.id,
                      'correct': correct,
                      'points': points,
                    });
                    if (!mounted) return;
                    Navigator.of(ctx).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "批改完成：${res['reason'] as String}"),
                        backgroundColor:
                            (res['changed'] as int) >= 0 ? Colors.green : Colors.red,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setDialogState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e is ApiException ? e.message : '批改失败'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('确认批改'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      _load();
    }
  }

  Widget _choiceChip(String label, bool value, ValueChanged<bool> onSelected) {
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF4ECDC4)
              : const Color(0xFFE0F5F4),
          borderRadius: BorderRadius.circular(999),
          border: value
              ? null
              : Border.all(color: const Color(0xFFBDE5E2)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                color: value ? Colors.white : const Color(0xFF3E7C77))),
      ),
    );
  }
}
