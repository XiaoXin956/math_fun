import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class LoginPage extends StatefulWidget {
  static const routeName = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submit(bool isRegister) async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      _error('请输入用户名和密码');
      return;
    }
    final cubit = context.read<AuthCubit>();
    if (isRegister && _nickname.text.trim().isEmpty) {
      _error('请输入昵称');
      return;
    }
    if (isRegister) {
      // 只开放家长注册；孩子账号由家长在首页添加
      await cubit.register({
        'username': username,
        'password': password,
        'nickname': _nickname.text.trim(),
        'role': 'parent',
      });
    } else {
      await cubit.login(username, password);
    }
    if (!mounted) return;
    final state = cubit.state;
    if (state.error != null) {
      _error(state.error!);
    }
    // 登录成功时 AuthState 携带 user，_AppShell 会自动切换到首页
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _brandHeader(),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: '登录'),
                                Tab(text: '注册'),
                              ],
                              labelColor: AppColors.brandDark,
                              unselectedLabelColor: AppColors.inkSoft,
                              indicatorColor: AppColors.brand,
                              indicatorWeight: 3,
                              labelStyle: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            SizedBox(
                              height: 380,
                              child: TabBarView(
                                children: [_loginForm(), _registerForm()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 品牌头图：渐变背景 + 装饰气泡 + 吉祥物，建立第一印象。
  Widget _brandHeader() {
    return Stack(
      children: [
        Container(
          height: 190,
          decoration: const BoxDecoration(
            gradient: AppGradients.hero,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(36),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 28,
                top: 28,
                child: _bubble(54, Colors.white.withValues(alpha: 0.16)),
              ),
              Positioned(
                right: 36,
                top: 60,
                child: _bubble(30, Colors.white.withValues(alpha: 0.14)),
              ),
              Positioned(
                right: 90,
                top: 20,
                child: _bubble(18, Colors.white.withValues(alpha: 0.2)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppShadows.medium,
                      ),
                      alignment: Alignment.center,
                      child: const Text('🧮', style: TextStyle(fontSize: 40)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '数学乐园',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '每天进步一点点 ✨',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _loginForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('欢迎回来 👋'),
          const SizedBox(height: 18),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            onSubmitted: (_) => _submit(false),
          ),
          const SizedBox(height: 24),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return BrandButton(
                '开始挑战',
                icon: Icons.rocket_launch_rounded,
                loading: state.isLoading,
                onPressed: () => _submit(false),
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Text(
              '💡 演示账号：parent / 123456（家长）或 xiaoming / 123456（孩子）',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _registerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('创建账号 ✨', accent: AppColors.purple),
          const SizedBox(height: 18),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名（3-20 位字母、数字、下划线）',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码（至少 6 位）',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nickname,
            decoration: const InputDecoration(
              labelText: '昵称',
              prefixIcon: Icon(Icons.emoji_emotions_outlined),
            ),
          ),
          const SizedBox(height: 22),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return BrandButton(
                '创建账号',
                icon: Icons.person_add_rounded,
                gradient: AppGradients.success,
                loading: state.isLoading,
                onPressed: () => _submit(true),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            '注册后可在首页添加孩子账号并查看成绩',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
