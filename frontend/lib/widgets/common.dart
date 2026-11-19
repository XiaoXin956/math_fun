import 'package:flutter/material.dart';

/// 年级选择条（一年级 ~ 六年级）。
class GradeChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const GradeChips({super.key, required this.selected, required this.onChanged});

  static const List<String> _labels =
      ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(6, (i) {
        final grade = i + 1;
        final isSelected = grade == selected;
        return GestureDetector(
          onTap: () => onChanged(grade),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF7A59) : const Color(0xFFFFE3DA),
              borderRadius: BorderRadius.circular(999),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFFFC9BC)),
            ),
            child: Text(
              '$grade 年级',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8A5A4A),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
        );
      }),
    );
  }

  static String labelOf(int grade) => _labels[grade - 1];
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
          onTap: () => onChanged(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4ECDC4) : const Color(0xFFE0F5F4),
              borderRadius: BorderRadius.circular(999),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFBDE5E2)),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF3E7C77),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          summary['mode'] == 'timed' ? '时间到！⏰' : '本轮完成 🎊',
          style: const TextStyle(fontSize: 22),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary['mode'] == 'timed'
                  ? "答对了 ${summary['correct']} 道题"
                  : "共 ${summary['total']} 题，答对 ${summary['correct']} 题",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '正确率：${(ratio * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 16),
            ),
            if (passed)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '闯关成功，获得星星 ⭐',
                  style: TextStyle(
                      fontSize: 16, color: const Color(0xFFE8842C)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('太棒了', style: TextStyle(fontSize: 18)),
          ),
        ],
      );
    },
  );
}
