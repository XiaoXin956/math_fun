import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';

/// 一组答题记录（同一天、同一玩法）。
class _RecordGroup {
  final String key;
  final String title;
  final List<Record> records;

  _RecordGroup(this.key, this.title, this.records);

  int get correctCount => records.where((r) => r.correct).length;
}

/// 成绩记录页：查看本人或（家长查看）某个孩子的历史答题记录。
/// 「全部记录」按 日期+玩法 分组；「错题回顾」直接平铺显示错题。
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
  // 已展开的分组 key（默认全部收起）
  final Set<String> _expanded = {};

  ApiClient get _client => Session.createClient();

  /// 把记录按「日期 + 玩法」聚合成组，保持服务端返回的时间倒序。
  List<_RecordGroup> _buildGroups() {
    final map = <String, _RecordGroup>{};
    for (final r in _records) {
      final key = '${r.dateLabel}|${r.mode}';
      // 记录按时间倒序，组内第一条即最新一条；取它的时分秒作为该组代表时间
      final time = r.timeLabel.length >= 19 ? r.timeLabel.substring(11) : '';
      final group = map.putIfAbsent(
        key,
        () => _RecordGroup(
          key,
          time.isEmpty
              ? '${r.dateLabel} ${r.modeGroupLabel}'
              : '${r.dateLabel} $time ${r.modeGroupLabel}',
          [],
        ),
      );
      group.records.add(r);
    }
    return map.values.toList();
  }

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
    // 每次加载默认全部收起分组
    if (_expanded.isNotEmpty) {
      setState(() => _expanded.clear());
    }
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
                          fontSize: 14, color: AppColors.inkSoft)),
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
                        : _wrongOnly
                            ? _wrongList()
                            : _groupedList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 错题回顾：平铺显示，不分组。
  Widget _wrongList() {
    return ListView.separated(
      itemCount: _records.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == _records.length) return _loadMoreButton();
        return _recordCard(_records[i]);
      },
    );
  }

  /// 全部记录：按「日期 + 玩法」分组，每组可展开/收起。
  Widget _groupedList() {
    final groups = _buildGroups();
    return ListView.builder(
      itemCount: groups.length + 1,
      itemBuilder: (_, i) {
        if (i == groups.length) return _loadMoreButton();
        return _groupCard(groups[i]);
      },
    );
  }

  Widget _groupCard(_RecordGroup group) {
    final expanded = _expanded.contains(group.key);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expanded.remove(group.key);
              } else {
                _expanded.add(group.key);
              }
            }),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('${group.correctCount}/${group.records.length}',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.surfaceAlt),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  for (final r in group.records) ...[
                    _recordCard(r, compact: true),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool wrong, IconData icon) {
    final selected = _wrongOnly == wrong;
    return Material(
      color: selected ? AppColors.brand : AppColors.surfaceAlt,
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
                  color: selected ? Colors.white : AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : AppColors.inkSoft)),
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
                style: TextStyle(fontSize: 13, color: AppColors.inkFaint))),
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

  Widget _recordCard(Record record, {bool compact = false}) {
    // 组内已标注日期和玩法，这里只显示具体时间点
    String timeText = record.timeLabel;
    if (compact && record.timeLabel.length >= 19) {
      timeText = record.timeLabel.substring(11, 19);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!compact)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(record.modeLabel,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.star)),
                  ),
                const Spacer(),
                Text(timeText,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              record.expression,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  record.correct ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: record.correct
                      ? AppColors.success
                      : AppColors.danger,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    record.correct
                        ? '答对了，我的答案 ${record.userAnswer} ✅'
                        : '答错了 ❌  我的答案 ${record.userAnswer}  ·  正确答案 ${record.answer}',
                    style: TextStyle(
                        fontSize: 13,
                        color: record.correct
                            ? AppColors.success
                            : AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
