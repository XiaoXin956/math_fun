import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';

/// 成绩记录页：查看本人或（家长查看）某个孩子的历史答题记录。
/// 支持「全部 / 错题回顾」切换，展示答题时间、题目、我的答案与正确答案。
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
  bool _loadingMore = false;
  bool _wrongOnly = false;
  int _total = 0;
  static const int _pageSize = 50;
  bool _initialized = false;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    // 不能在此调用 ModalRoute.of(context)：它依赖 InheritedWidget，
    // 在 initState 完成前访问会抛断言。移到 didChangeDependencies。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final cid = args['childId'];
      if (cid is int) _childId = cid;
      final name = args['childName'];
      if (name is String && name.isNotEmpty) _title = "$name 的成绩";
      // 从首页「错题回顾」入口进入时直接定位到错题页
      if (args['wrongOnly'] == true) {
        _wrongOnly = true;
        _title = '错题回顾';
      }
    }
    _load();
  }

  Future<void> _load() async {
    // 加载状态由 _fetch 内部统一设置，避免重复 setState 与鼠标设备更新冲突
    await _fetch(reset: true);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (!reset && _loadingMore) return;
    if (reset) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    final limit = _pageSize + (reset ? 0 : _records.length);
    try {
      final query = <String, String>{
        'limit': '$limit',
        if (_wrongOnly) 'wrongOnly': '1',
      };
      final res = _childId == null
          ? await _client.get('/api/history', query: query)
          : await _client.get('/api/children/$_childId/history', query: query);
      if (!mounted) return;
      setState(() {
        _records = (res['records'] as List)
            .map((e) => Record.fromJson(e as Map<String, dynamic>))
            .toList();
        final t = res['total'];
        _total = t is int ? t : (t is num ? t.toInt() : _records.length);
      });
    } catch (e) {
      // 显示错误原因，避免静默失败难以排查
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载记录失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _switchMode(bool wrongOnly) {
    if (_wrongOnly == wrongOnly) return;
    setState(() => _wrongOnly = wrongOnly);
    // 延迟到帧后加载，避免点击回调里同步重建与 MouseTracker 设备更新冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
              // 全部 / 错题回顾 切换
              Row(
                children: [
                  Expanded(
                    child: _modeChip('全部记录', false, Icons.list_alt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _modeChip('错题回顾', true, Icons.error_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('共 $_total 条${_wrongOnly ? '错题' : '记录'}',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF8A5A4A))),
                  TextButton(onPressed: _load, child: const Text('刷新')),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? Center(
                            child: Text(_wrongOnly
                                ? '太棒了，还没有错题！'
                                : '还没有答题记录'))
                        : ListView.separated(
                            itemCount: _records.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              if (i == _records.length) {
                                return _loadMoreButton();
                              }
                              return _recordCard(_records[i]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool wrong, IconData icon) {
    final selected = _wrongOnly == wrong;
    return Material(
      color: selected ? const Color(0xFFFF7A59) : const Color(0xFFFFF0E8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _switchMode(wrong),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF8A5A4A)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : const Color(0xFF8A5A4A))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadMoreButton() {
    if (_records.length >= _total) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: Text('没有更多了',
                style: TextStyle(fontSize: 13, color: Color(0xFFB09A8E)))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : TextButton(
                onPressed: () => _fetch(reset: false),
                child: const Text('加载更多'),
              ),
      ),
    );
  }

  Widget _recordCard(Record record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(record.modeLabel,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFE8842C))),
                ),
                const Spacer(),
                Text(record.timeLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8A5A4A))),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.expression,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A3E36)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  record.correct ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: record.correct
                      ? const Color(0xFF2E9E5B)
                      : const Color(0xFFD9534F),
                ),
                const SizedBox(width: 6),
                Text(
                  record.correct
                      ? '答对了，我的答案 ${record.userAnswer} ✅'
                      : '答错了 ❌  我的答案 ${record.userAnswer}  ·  正确答案 ${record.answer}',
                  style: TextStyle(
                      fontSize: 14,
                      color: record.correct
                          ? const Color(0xFF2E9E5B)
                          : const Color(0xFFD9534F)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
