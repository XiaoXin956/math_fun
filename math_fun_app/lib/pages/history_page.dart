import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';

/// 成绩记录页：查看本人或（家长查看）某个孩子的历史答题记录。
class HistoryPage extends StatefulWidget {
  static const routeName = '/history';

  /// arguments: {'childId': int, 'childName': String}（家长查看孩子时传入）
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int? _childId;
  String _title = '我的成绩';
  List<Record> _records = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _childId = args['childId'] as int;
      _title = "${args['childName'] as String} 的成绩";
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = _childId == null
          ? await _client.get('/api/history')
          : await _client.get('/api/children/$_childId/history');
      if (!mounted) return;
      setState(() {
        _records = (res['records'] as List)
            .map((e) => Record.fromJson(e as Map<String, dynamic>))
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
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('最近答题记录',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                      onPressed: _load, child: const Text('刷新')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? const Center(child: Text('还没有答题记录'))
                        : ListView.separated(
                            itemCount: _records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _recordCard(_records[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordCard(Record record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(record.modeLabel,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFE8842C))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.expression,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(record.correct
                      ? '答对了 ✅'
                      : '答错了 ❌ 正确答案：${record.answer}',
                      style: TextStyle(
                          fontSize: 13,
                          color: record.correct
                              ? const Color(0xFF2E9E5B)
                              : const Color(0xFFD9534F)),
                      ),
                ],
              ),
            ),
            Text(record.timeLabel, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
