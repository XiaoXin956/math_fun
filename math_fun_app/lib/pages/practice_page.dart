import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/question_runner.dart';

/// 自由练习：选择年级与运算，每次 10 题。
class PracticePage extends StatefulWidget {
  static const routeName = '/practice';
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  int _grade = 2;
  String _operation = 'mixed';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎯 自由练习')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('选择年级',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GradeChips(selected: _grade, onChanged: (g) => setState(() => _grade = g)),
              const SizedBox(height: 24),
              const Text('选择运算（可混合）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              OperationChips(
                  selected: _operation, onChanged: (o) => setState(() => _operation = o)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuestionRunner(
                        grade: _grade,
                        operation: _operation,
                        mode: 'practice',
                        totalQuestions: 10,
                      ),
                    ),
                  );
                },
                child: const Text('开始练习（10 题）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
