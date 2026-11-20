import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../bloc/auth_cubit.dart';
import '../models/models.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

/// 家长批改手写答案：一次练习（批次）为一组，整组判定对错并给一个分（0-10），
/// 批改完成整组后一次性结算积分。
class ReviewPage extends StatefulWidget {
  static const routeName = '/review';
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<HandwritingBatch> _batches = [];
  bool _loading = true;
  final Set<String> _submitting = {};

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
        _batches = (res['batches'] as List? ?? [])
            .map((e) => HandwritingBatch.fromJson(e as Map<String, dynamic>))
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
      appBar: AppBar(title: const Text('手写答案批改')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionTitle('待批改练习', accent: AppColors.brand),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('刷新'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _batches.isEmpty
                        ? const Center(child: Text('没有待批改的练习 🎉'))
                        : ListView.separated(
                            itemCount: _batches.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _batchCard(_batches[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一组一张卡：孩子、时间、题数、缩略图预览。
  Widget _batchCard(HandwritingBatch batch) {
    final submitting = _submitting.contains(batch.batchId);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: submitting ? null : () => _review(batch),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceAlt,
                    child: const Text('👦', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(batch.childName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          '${batch.createdAt} · 共 ${batch.items.length} 题',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.brand),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: batch.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Image.memory(
                      _decodeImage(batch.items[i].image),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported_outlined,
                              size: 24, color: AppColors.inkFaint),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text('点击整组批改 →',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List _decodeImage(String base64Str) {
    final clean = base64Str.contains(',')
        ? base64Str.substring(base64Str.indexOf(',') + 1)
        : base64Str;
    return base64Decode(clean.replaceAll('\n', ''));
  }

  Future<void> _review(HandwritingBatch batch) async {
    bool correct = true;
    int points = 5;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            title: const Text('批改手写练习', style: AppText.title),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${batch.childName} · 共 ${batch.items.length} 题 · 整组一次给分',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.inkSoft)),
                    const SizedBox(height: 12),
                    // 整组 5 题：图片 + 算式 + 参考答案
                    ...batch.items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xs),
                                ),
                                child: Image.memory(
                                  _decodeImage(item.image),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('🖼️',
                                          style: TextStyle(fontSize: 18)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(item.expression,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ),
                              Text('= ${item.answer}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.inkSoft)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                    const Text('整组判定', style: AppText.caption),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _choiceChip('答对了', true, correct, AppColors.success,
                            (v) => setDialogState(() => correct = v)),
                        const SizedBox(width: 12),
                        _choiceChip('答错了', false, correct, AppColors.danger,
                            (v) => setDialogState(() => correct = v)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => setDialogState(
                                () => points = points == 0 ? 0 : points - 1)),
                        Text('积分 $points',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setDialogState(
                                () => points = points >= 10 ? 10 : points + 1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '整组判定正确加 $points 分，错误扣 $points 分（0-10），批改后一次性结算',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _submitting.add(batch.batchId));
                  try {
                    final res = await _client.post('/api/handwriting/review', {
                      'batch_id': batch.batchId,
                      'correct': correct,
                      'points': points,
                    });
                    if (!mounted) return;
                    Navigator.of(ctx).pop(true);
                    context.read<AuthCubit>().refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('批改完成：${res['reason'] as String}'),
                        backgroundColor: (res['changed'] as int) >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(e is ApiException ? e.message : '批改失败'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _submitting.remove(batch.batchId));
                    }
                  }
                },
                child: const Text('确认批改整组'),
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

  Widget _choiceChip(String label, bool value, bool selected, Color activeColor,
      ValueChanged<bool> onSelected) {
    final isActive = value == selected;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: isActive ? null : Border.all(color: AppColors.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : AppColors.inkSoft)),
      ),
    );
  }
}
