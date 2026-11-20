import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 分类选择条：年级（1-6）与数值范围（101-105）两组并列。
class GradeChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const GradeChips({super.key, required this.selected, required this.onChanged});

  static const List<String> _labels =
      ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];
  // 101-105 对应 10/20/50/100/1000 以内
  static const List<String> _rangeLabels =
      ['10以内', '20以内', '50以内', '100以内', '1000以内'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text('按年级',
              style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(6, (i) {
            final grade = i + 1;
            return _chip(grade, '$grade 年级');
          }),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 2, top: 14, bottom: 8),
          child: Text('按数值范围',
              style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(5, (i) {
            final grade = 101 + i;
            return _chip(grade, _rangeLabels[i]);
          }),
        ),
      ],
    );
  }

  Widget _chip(int grade, String label) {
    final isSelected = grade == selected;
    return GestureDetector(
      // 点击当前已选项不触发回调，避免无意义的重新加载
      onTap: isSelected ? null : () => onChanged(grade),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.purple, AppColors.brandLight])
              : null,
          color: isSelected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.purple : AppColors.line,
            width: isSelected ? 0 : 1.5,
          ),
          boxShadow: isSelected ? AppShadows.soft : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.inkSoft,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  /// 年级/范围编码 -> 中文标签
  static String labelOf(int grade) {
    if (grade >= 101 && grade <= 105) {
      return _rangeLabels[grade - 101];
    }
    if (grade >= 1 && grade <= 6) {
      return _labels[grade - 1];
    }
    return '$grade';
  }
}

/// 练习模式的运算选择条。
class OperationChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const OperationChips({super.key, required this.selected, required this.onChanged});

  static const Map<String, String> _ops = {
    'mixed': '混合运算',
    'add': '加法 +',
    'sub': '减法 −',
    'mul': '乘法 ×',
    'div': '除法 ÷',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _ops.entries.map((e) {
        final isSelected = e.key == selected;
        return GestureDetector(
          // 点击当前已选运算不触发回调，避免无意义的重建
          onTap: isSelected ? null : () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              gradient: isSelected ? AppGradients.success : null,
              color: isSelected ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isSelected ? AppColors.success : AppColors.line,
                width: isSelected ? 0 : 1.5,
              ),
              boxShadow: isSelected ? AppShadows.soft : null,
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.inkSoft,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 生成星星文本，如 starText(2) => "⭐⭐☆"
String starText(int count) {
  final filled = List.generate(count, (_) => '⭐').join();
  final empty = List.generate(3 - count, (_) => '☆').join();
  return '$filled$empty';
}

/// 答题结束的结算弹窗。
/// summary: {mode, grade, correct, total, seconds}
Future<void> showSummaryDialog(
    BuildContext context, Map<String, dynamic> summary) {
  final passed = summary['mode'] == 'challenge' &&
      (summary['correct'] as int) * 10 >= (summary['total'] as int) * 7;
  final ratio = summary['total'] as int > 0
      ? (summary['correct'] as int) / (summary['total'] as int)
      : 0;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                shape: BoxShape.circle,
                boxShadow: AppShadows.medium,
              ),
              alignment: Alignment.center,
              child: Text(
                summary['mode'] == 'timed' ? '⏰' : '🏆',
                style: const TextStyle(fontSize: 38),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              summary['mode'] == 'timed' ? '时间到！' : '太棒了，完成啦！',
              textAlign: TextAlign.center,
              style: AppText.headline,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              summary['mode'] == 'timed'
                  ? "答对了 ${summary['correct']} 道题"
                  : "共 ${summary['total']} 题，答对 ${summary['correct']} 题",
              style: const TextStyle(fontSize: 17, color: AppColors.ink),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '正确率 ${(ratio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success),
              ),
            ),
            if (summary['points'] is Map<String, dynamic>)
              Builder(builder: (context) {
                final pts = summary['points'] as Map<String, dynamic>;
                final changed = pts['changed'] as int? ?? 0;
                final reason = pts['reason'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    changed > 0
                        ? '积分 +$changed（$reason）'
                        : reason.isNotEmpty
                            ? reason
                            : '本次不加分',
                    style: TextStyle(
                        fontSize: 15,
                        color: changed > 0
                            ? AppColors.success
                            : AppColors.inkSoft),
                  ),
                );
              }),
            if (passed)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '闯关成功，获得星星 ⭐',
                  style: TextStyle(
                      fontSize: 16, color: AppColors.star),
                ),
              ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
                child: const Text('继续加油'),
              ),
            ),
          ),
        ],
      );
    },
  );
}
