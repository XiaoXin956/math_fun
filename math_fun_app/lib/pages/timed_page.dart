import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/common.dart';
import '../widgets/question_runner.dart';

/// 限时挑战：60 秒内尽可能多答题，记录最佳成绩。
class TimedPage extends StatefulWidget {
  static const routeName = '/timed';
  const TimedPage({super.key});

  @override
  State<TimedPage> createState() => _TimedPageState();
}

class _TimedPageState extends State<TimedPage> {
  int _grade = 2;
  List<Map<String, dynamic>> _best = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    try {
      final res = await _client.get('/api/progress/timed');
      if (!mounted) return;
      setState(() {
        _best = (res['best'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList()
          ..sort((a, b) => (a['grade'] as int).compareTo(b['grade'] as int));
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
      appBar: AppBar(title: const Text('⏰ 限时挑战')),
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
              const SizedBox(height: 20),
              const Text(
                '60 秒倒计时，答对越多分数越高！',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _best.isEmpty
                        ? const Center(child: Text('还没有挑战记录，快开始吧！'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('各年级最佳成绩',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.inkSoft)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _best.length,
                                  itemBuilder: (_, i) {
                                    final b = _best[i];
                                    final grade = b['grade'] as int;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                          backgroundColor: AppColors.infoSoft,
                                          child: Text('$grade',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.info)),
                                        ),
                                        title:
                                            Text('${GradeChips.labelOf(grade)} 最佳成绩',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700)),
                                        subtitle: Text('答对 ${b['correct']} 题',
                                            style: const TextStyle(fontSize: 13)),
                                        trailing: Text('${b['score']} 分',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.info)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
              const SizedBox(height: 12),
              BrandButton(
                '开始 60 秒挑战',
                icon: Icons.bolt_rounded,
                gradient: const LinearGradient(colors: [
                  AppColors.info,
                  Color(0xFF3D6B93)]),
                onPressed: _play,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _play() async {
    final summary = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => QuestionRunner(
          grade: _grade,
          operation: 'mixed',
          mode: 'timed',
          onComplete: (summary) {
            Navigator.of(context).pop(summary);
          },
        ),
      ),
    );
    if (summary == null || !mounted) return;

    try {
      await _client.post('/api/progress/timed', {
        'grade': _grade,
        'score': summary['correct'],
        'correct': summary['correct'],
      });
    } catch (_) {
      // 成绩上报失败不影响展示
    }
    _loadBest();
  }
}
