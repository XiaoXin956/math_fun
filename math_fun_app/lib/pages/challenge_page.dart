import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../bloc/auth_cubit.dart';
import '../models/models.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/question_runner.dart';

/// 闯关模式：每个年级 10 关，答对率 ≥70% 通关并获得星星。
class ChallengePage extends StatefulWidget {
  static const routeName = '/challenge';
  const ChallengePage({super.key});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> {
  int _grade = 2;
  LevelInfo? _currentLevel;
  List<LevelInfo> _levels = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    try {
      final res = await _client.get('/api/progress/challenge',
          query: {'grade': '$_grade'});
      if (!mounted) return;
      setState(() {
        _levels = (res['levels'] as List)
            .map((e) => LevelInfo.fromJson(e as Map<String, dynamic>))
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
      appBar: AppBar(title: const Text('🏆 闯关挑战')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('选择年级',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GradeChips(
                  selected: _grade,
                  onChanged: (g) => setState(() {
                    _grade = g;
                    _loadProgress();
                  })),
              const SizedBox(height: 24),
              const Text(
                '每个年级 10 关，正确率 ≥ 70% 即可通关 ⭐',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                LayoutBuilder(builder: (context, constraints) {
                  // 按屏宽自适应列数：卡片最小宽度 110，间距 12
                  const minCardWidth = 110.0;
                  const spacing = 12.0;
                  final available = constraints.maxWidth;
                  final columns = ((available + spacing) /
                          (minCardWidth + spacing))
                      .floor()
                      .clamp(2, 6);
                  final cardWidth =
                      (available - spacing * (columns - 1)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: _levels
                        .map((level) => SizedBox(
                              width: cardWidth,
                              child: _levelCard(level),
                            ))
                        .toList(),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(LevelInfo level) {
    final Color badgeColor;
    if (level.passed) {
      badgeColor = AppColors.star;
    } else if (level.unlocked) {
      badgeColor = AppColors.purple;
    } else {
      badgeColor = AppColors.inkFaint;
    }
    final String status;
    final Color statusColor;
    if (level.passed) {
      status = '✓ 已通关';
      statusColor = AppColors.success;
    } else if (level.unlocked) {
      status = '可挑战';
      statusColor = AppColors.purple;
    } else {
      status = '未解锁';
      statusColor = AppColors.inkFaint;
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: level.unlocked ? () => _playLevel(level) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: level.passed ? AppColors.star.withValues(alpha: 0.5) : AppColors.line,
              width: level.passed ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: level.unlocked
                      ? LinearGradient(colors: [
                          badgeColor,
                          badgeColor.withValues(alpha: 0.7)])
                      : null,
                  color: level.unlocked ? null : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  boxShadow: level.unlocked ? AppShadows.soft : null,
                ),
                child: Text(
                  level.passed ? '🏆' : (level.unlocked ? '${level.level}' : '🔒'),
                  style: TextStyle(
                    fontSize: level.passed ? 26 : 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('第 ${level.level} 关',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${level.questions} 题',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.inkSoft)),
              const SizedBox(height: 6),
              Text(starText(level.stars),
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playLevel(LevelInfo level) async {
    _currentLevel = level;
    final summary = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => QuestionRunner(
          grade: _grade,
          operation: 'mixed',
          mode: 'challenge',
          totalQuestions: level.questions,
          onComplete: (summary) {
            Navigator.of(context).pop(summary);
          },
          onExitRequested: () async {
            final ok = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('确认退出本关？'),
                content: const Text(
                  '中途退出本关将扣除 5 积分，确定要退出吗？',
                  style: TextStyle(fontSize: 16),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('继续答题')),
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('确认退出',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (ok == true && _currentLevel != null) {
              try {
                await _client.post('/api/progress/challenge/quit', {
                  'grade': _grade,
                  'level': _currentLevel!.level,
                });
                // 积分有变动，刷新用户状态让首页同步
                context.read<AuthCubit>().refresh();
              } catch (_) {
                // 扣分失败不阻塞退出
              }
            }
            return ok == true;
          },
        ),
      ),
    );
    _currentLevel = null;
    if (summary == null || !mounted) return;

    // 上报成绩并显示结果
    try {
      final res = await _client.post('/api/progress/challenge', {
        'grade': _grade,
        'level': level.level,
        'correct': summary['correct'],
        'total': summary['total'],
      });
      final passed = res['passed'] as bool;
      final stars = res['stars'] as int;
      final points = res['points'] as Map<String, dynamic>;
      final pointsText =
          "积分变动：${points['changed'] as int >= 0 ? '+' : ''}${points['changed'] as int}（${points['reason'] as String}）";
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(passed ? '闯关成功！🎉' : '差一点点，再试一次💪',
              style: const TextStyle(fontSize: 22)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("第 ${level.level} 关：答对 ${summary['correct']} / ${summary['total']} 题",
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('获得 ${starText(stars)}',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              Text(
                pointsText,
                style: TextStyle(
                    fontSize: 15,
                    color: (points['changed'] as int) >= 0
                        ? AppColors.success
                        : AppColors.danger),
              ),
              if (passed && res['nextUnlocked'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('下一关已解锁！',
                      style: TextStyle(fontSize: 16, color: AppColors.success)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('返回')),
          ],
        ),
      );
      // 积分有变动，刷新用户状态让首页同步
      context.read<AuthCubit>().refresh();
      _loadProgress();
    } catch (_) {
      // 上报失败也返回列表
      _loadProgress();
    }
  }
}
