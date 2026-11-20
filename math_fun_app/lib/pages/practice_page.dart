import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
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
  int _dailyUsed = 0;
  int _dailyLimit = 5;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    _loadDaily();
  }

  Future<void> _loadDaily() async {
    try {
      final res = await _client.get('/api/practice/daily');
      if (!mounted) return;
      setState(() {
        _dailyUsed = res['used'] as int;
        _dailyLimit = res['limit'] as int;
      });
    } catch (_) {
      // 加载失败不阻塞练习，保持默认显示
    }
  }

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
              const SectionTitle('① 选择年级', accent: AppColors.purple),
              const SizedBox(height: 14),
              GradeChips(
                  selected: _grade,
                  onChanged: (g) => setState(() => _grade = g)),
              const SizedBox(height: 28),
              const SectionTitle('② 选择运算', accent: AppColors.success),
              const SizedBox(height: 14),
              OperationChips(
                  selected: _operation,
                  onChanged: (o) => setState(() => _operation = o)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tips_and_updates_rounded,
                            color: AppColors.info, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('正确率超过 90% 可获得积分奖励，每天前 5 次有效哦',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.inkSoft)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.today_rounded,
                            color: AppColors.danger, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '今日已使用有效次数：$_dailyUsed / $_dailyLimit 次',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BrandButton(
                '开始练习 · 10 题',
                icon: Icons.play_arrow_rounded,
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuestionRunner(
                        grade: _grade,
                        operation: _operation,
                        mode: 'practice',
                        totalQuestions: 10,
                      ),
                    ),
                  );
                  // 答完回来刷新今日已用次数
                  if (mounted) _loadDaily();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
