import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';

/// 积分记录：当前积分 + 变动明细。
class PointsPage extends StatefulWidget {
  static const routeName = '/points';
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  int _total = 0;
  List<PointsRecord> _records = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _client.get('/api/points');
      if (!mounted) return;
      setState(() {
        _total = res['total'] as int;
        _records = (res['records'] as List)
            .map((e) => PointsRecord.fromJson(e as Map<String, dynamic>))
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
      appBar: AppBar(title: const Text('🎖️ 积分记录')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A59), Color(0xFFFF9E7D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('当前积分',
                        style: TextStyle(
                            fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text('$_total',
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('积分明细',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? const Center(child: Text('暂无积分变动记录'))
                        : ListView.separated(
                            itemCount: _records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _card(_records[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(PointsRecord record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: record.change >= 0
                    ? const Color(0xFFE5F6EC)
                    : const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                record.change >= 0 ? '+${record.change}' : '${record.change}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: record.change >= 0
                        ? const Color(0xFF2E9E5B)
                        : const Color(0xFFD9534F)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.reason,
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(record.timeLabel,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFB09A8E))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
