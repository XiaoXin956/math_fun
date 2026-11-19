import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/session.dart';
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
                style: TextStyle(fontSize: 14, color: Color(0xFF8A5A4A)),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_best.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('还没有挑战记录，快开始吧！')),
                )
              else
                ..._best.map((b) {
                  final grade = b['grade'] as int;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: const Icon(Icons.bolt, color: Color(0xFFE8842C)),
                      title: Text("$grade 年级最佳：${b['score']} 分",
                          style: const TextStyle(fontSize: 16)),
                      subtitle: Text("答对 ${b['correct']} 题",
                          style: const TextStyle(fontSize: 13)),
                    ),
                  );
                }),
              const Spacer(),
              ElevatedButton(
                onPressed: _play,
                child: const Text('开始 60 秒挑战'),
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
