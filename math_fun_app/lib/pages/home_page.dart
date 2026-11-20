import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

import '../api/api_client.dart';
import '../bloc/auth_cubit.dart';
import '../models/models.dart';
import '../services/session.dart';
import 'handwriting_page.dart';
import 'history_page.dart';
import 'points_page.dart';
import 'review_page.dart';

class HomePage extends StatefulWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Child> _children = [];
  bool _loading = true;

  ApiClient get _client => Session.createClient();

  /// 当前登录用户来自 AuthCubit（全局状态由 BLoC 管理）
  User get _user => context.read<AuthCubit>().state.user!;

  @override
  void initState() {
    super.initState();
    if (_user.isParent) {
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
    // 由 AuthCubit 统一处理登出，状态变化后 _AppShell 会自动切回登录页
    await context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    // watch：积分等用户状态变化时自动重建
    final user = context.watch<AuthCubit>().state.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('正在加载…')));
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
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.purpleSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: AppColors.purple, size: 24),
                    ),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(user.isParent ? '👨‍👩‍👧' : '🧒',
                    style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你好，${user.nickname}！',
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      user.isParent
                          ? '家长账号 · 管理孩子与查看成绩'
                          : '一起来算术吧',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _accountMenu(user),
            ],
          ),
          if (!user.isParent) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    color: AppColors.star, size: 20),
                const SizedBox(width: 8),
                const Text('当前积分',
                    style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                const Spacer(),
                Text(
                  '${user.points}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                ),
              ],
            ),
          ],
        ],
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
        leading: CircleAvatar(
          backgroundColor: AppColors.infoSoft,
          child: const Text('👦'),
        ),
        title: Text(child.nickname,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '已答题 ${child.totalAnswered} 题 · '
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
        const SectionTitle('选择玩法', accent: AppColors.brand),
        const SizedBox(height: 14),
        _modeCard('🎯', '自由练习', '按年级与运算自由刷题', AppColors.brand, () {
          Navigator.of(context).pushNamed('/practice');
        }),
        const SizedBox(height: 12),
        _modeCard('🏆', '闯关挑战', '一关一关推进，赢星星', AppColors.purple, () {
          Navigator.of(context).pushNamed('/challenge');
        }),
        const SizedBox(height: 12),
        _modeCard('⏰', '限时挑战', '60 秒内答得越多越棒', AppColors.info, () {
          Navigator.of(context).pushNamed('/timed');
        }),
        const SizedBox(height: 12),
        _modeCard('✍️', '手写练习', '手写答案，交家长批改', AppColors.success, () {
          Navigator.of(context).pushNamed(HandwritingPage.routeName);
        }),
        const SizedBox(height: 12),
        _modeCard('📕', '错题回顾', '集中复习做错的题目', AppColors.star, () {
          Navigator.of(context).pushNamed(
            HistoryPage.routeName,
            arguments: {'wrongOnly': true},
          );
        }),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _quickLink(Icons.emoji_events_rounded, '积分记录',
                AppColors.star, () {
              Navigator.of(context).pushNamed(PointsPage.routeName);
            })),
            const SizedBox(width: 12),
            Expanded(child: _quickLink(Icons.bar_chart_rounded, '我的成绩',
                AppColors.info, () {
              Navigator.of(context).pushNamed(HistoryPage.routeName);
            })),
          ],
        ),
      ],
    );
  }

  /// 次级快捷入口：并排两个彩色小卡。
  Widget _quickLink(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(String icon, String title, String desc, Color color,
      VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              IconBadge(icon, color: color, size: 58, emojiSize: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 24),
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
              backgroundColor: AppColors.surfaceAlt,
              child: Text('⏻', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "${user.username}（${user.isParent ? '家长' : '孩子'}）",
                style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
            ),
            Text(
              user.username,
              style: const TextStyle(fontSize: 13, color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  /// 账号菜单：切换账号 / 退出登录。放在顶部信息卡右侧。
  Widget _accountMenu(User user) {
    return PopupMenuButton<String>(
      tooltip: '账号切换 / 退出登录',
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(Icons.logout_rounded,
            size: 18, color: AppColors.inkSoft),
      ),
      offset: const Offset(0, 44),
      onSelected: (value) {
        if (value == '__logout__') {
          _logout();
        } else {
          _switchAccount(value, user);
        }
      },
      itemBuilder: (context) {
        final others = Session.savedAccounts
            .where((a) => a.username != user.username)
            .toList();
        return [
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('切换账号',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.inkFaint)),
          ),
          if (others.isEmpty)
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('暂无其它已记住的账号',
                  style: TextStyle(fontSize: 13, color: AppColors.inkFaint)),
            )
          else
            ...others.map(
              (a) => PopupMenuItem<String>(
                value: a.username,
                child: Row(
                  children: [
                    const Icon(Icons.switch_account, size: 18,
                        color: AppColors.star),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.nickname.isNotEmpty ? a.nickname : a.username,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: '__logout__',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18, color: AppColors.danger),
                SizedBox(width: 10),
                Text('退出登录', style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
        ];
      },
    );
  }

  Future<void> _switchAccount(String username, User current) async {
    final account = Session.savedAccounts
        .where((a) => a.username == username)
        .toList();
    if (account.isEmpty) return;
    await context.read<AuthCubit>().switchAccount(account.first);
    if (!mounted) return;
    final err = context.read<AuthCubit>().state.error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddChildDialog() async {
  final username = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
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
