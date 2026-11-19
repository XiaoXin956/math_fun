import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';
import 'handwriting_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'points_page.dart';
import 'review_page.dart';

class HomePage extends StatefulWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  List<Child> _children = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  @override
  void initState() {
    super.initState();
    _user = Session.user;
    if (_user?.isParent ?? false) {
      _loadChildren();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadChildren() async {
    try {
      final res = await _client.get('/api/children');
      if (!mounted) return;
      setState(() {
        _children = (res['children'] as List)
            .map((e) => Child.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // 出错保持原状
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _client.post('/api/auth/logout', {});
    } catch (_) {
      // 忽略登出请求失败
    }
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('正在加载…'));
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _greetingCard(user),
            const SizedBox(height: 24),
            if (user.isParent) ...[
              _panelCard(
                title: '🖊️ 待批改',
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(4),
                    leading: const Icon(Icons.edit_note,
                        color: Color(0xFFE8842C), size: 30),
                    title: const Text('手写答案批改',
                        style: TextStyle(fontSize: 16)),
                    subtitle: const Text('查看孩子提交的手写答案，判断对错并打分'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed(ReviewPage.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _panelCard(
                title: '👨‍👩‍👧 家长面板',
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('我的孩子', style: TextStyle(fontSize: 16)),
                      TextButton(
                        onPressed: _showAddChildDialog,
                        child: const Text('+ 添加孩子'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_children.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('还没有孩子账号，点击「添加孩子」开始'),
                      ),
                    )
                  else
                    ..._children.map((c) => _childCard(c)),
                ],
              ),
            ] else
              _modeCards(),
            const SizedBox(height: 24),
            _profileCard(user),
          ],
        ),
      ),
    );
  }

  Widget _greetingCard(User user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFFFE3DA),
              child: Text('🧒', style: TextStyle(fontSize: 34)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你好，${user.nickname}！',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.isParent
                        ? '家长账号 · 管理孩子与查看成绩'
                        : '${user.grade ?? 2} 年级 · 一起来算术吧',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF8A5A4A)),
                  ),
                  if (!user.isParent) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🎖️ 当前积分：${user.points}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE8842C)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _childCard(Child child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0F5F4),
          child: Text('👦'),
        ),
        title: Text(child.nickname,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${child.grade} 年级 · 已答题 ${child.totalAnswered} 题 · '
          '正确率 ${(child.accuracy * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(
          HistoryPage.routeName,
          arguments: {'childId': child.id, 'childName': child.nickname},
        ),
      ),
    );
  }

  Widget _modeCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('选择玩法',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _modeCard('🎯', '自由练习', '按年级与运算自由刷题', () {
          Navigator.of(context).pushNamed('/practice');
        }),
        const SizedBox(height: 12),
        _modeCard('🏆', '闯关挑战', '一关一关推进，赢星星', () {
          Navigator.of(context).pushNamed('/challenge');
        }),
        const SizedBox(height: 12),
        _modeCard('⏰', '限时挑战', '60 秒内答得越多越棒', () {
          Navigator.of(context).pushNamed('/timed');
        }),
        const SizedBox(height: 12),
        _modeCard('✍️', '手写练习', '手写答案，交家长批改', () {
          Navigator.of(context).pushNamed(HandwritingPage.routeName);
        }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed(PointsPage.routeName),
          icon: const Icon(Icons.star_rate_outlined),
          label: const Text('积分记录'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.of(context).pushNamed(HistoryPage.routeName),
          icon: const Icon(Icons.history),
          label: const Text('我的成绩'),
        ),
      ],
    );
  }

  Widget _modeCard(String icon, String title, String desc, VoidCallback onTap) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(desc,
                        style:
                            const TextStyle(fontSize: 13, color: Color(0xFF8A5A4A))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(User user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFFFF0E8),
              child: Text('⏻', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "${user.username}（${user.isParent ? '家长' : '孩子'}）",
                style: const TextStyle(fontSize: 14, color: Color(0xFF8A5A4A)),
              ),
            ),
            TextButton(onPressed: _logout, child: const Text('退出登录')),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddChildDialog() async {
  final username = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  int grade = 2;
  String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('添加孩子账号'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                TextField(controller: username,
                    decoration: const InputDecoration(
                        labelText: '用户名', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: '密码（至少 6 位）',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: nickname,
                    decoration: const InputDecoration(
                        labelText: '昵称', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('年级', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                GradeChipsPicker(
                  selected: grade,
                  onChanged: (g) => setDialogState(() => grade = g),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _client.post('/api/children', {
                      'username': username.text.trim(),
                      'password': password.text,
                      'nickname': nickname.text.trim(),
                      'grade': grade,
                    });
                    if (!mounted) return;
                    Navigator.of(ctx).pop('ok');
                  } catch (e) {
                    if (!mounted) return;
                    setDialogState(() => error =
                        e is ApiException ? e.message : '添加失败');
                  }
                },
                child: const Text('添加'),
              ),
            ],
          );
        },
      ),
    );

    if (result == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('孩子账号已添加 🎉')),
      );
      _loadChildren();
    }
  }
}

// 对话框内部需要可更新的年级选择，独立成组件避免 StatefulBuilder 闭包问题
class GradeChipsPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const GradeChipsPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(6, (i) {
        final grade = i + 1;
        final isSelected = grade == selected;
        return GestureDetector(
          onTap: () => onChanged(grade),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF7A59) : const Color(0xFFFFE3DA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$grade 年级',
                style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.white : const Color(0xFF8A5A4A))),
          ),
        );
      }),
    );
  }
}
