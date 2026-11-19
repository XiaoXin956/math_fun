import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/question_runner.dart';

/// 闯关模式：每个年级 5 关，答对率 ≥70% 通关并获得星星。
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
        child: Padding(
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
                '每个年级 5 关，正确率 ≥ 70% 即可通关 ⭐',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A5A4A)),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _levels.length,
                  itemBuilder: (_, i) => _levelCard(_levels[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(LevelInfo level) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: level.unlocked ? () => _playLevel(level) : null,
        child: Column(
          children: [
            const Text('🚩', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text('第 ${level.level} 关',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${level.questions} 题',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A4A))),
            const SizedBox(height: 6),
            Text(
              starText(level.stars),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 2),
            if (level.passed)
              const Text('已通关', style: TextStyle(fontSize: 12, color: Color(0xFF2E9E5B)))
            else if (level.unlocked)
              const Text('可挑战', style: TextStyle(fontSize: 12, color: Color(0xFFE8842C)))
            else
              const Text('🔒 未解锁', style: TextStyle(fontSize: 12, color: Color(0xFFB09A8E))),
          ],
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
                        ? const Color(0xFF2E9E5B)
                        : const Color(0xFFD9534F)),
              ),
              if (passed && res['nextUnlocked'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('下一关已解锁！',
                      style: TextStyle(fontSize: 16, color: Color(0xFF2E9E5B))),
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
      _loadProgress();
    } catch (_) {
      // 上报失败也返回列表
      _loadProgress();
    }
  }
}
