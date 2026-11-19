import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();

  String _role = 'child'; // child / parent
  int _grade = 2;

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
      await cubit.register({
        'username': username,
        'password': password,
        'nickname': _nickname.text.trim(),
        'role': _role,
        'grade': _role == 'child' ? _grade : null,
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
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: const [Tab(text: '登录'), Tab(text: '注册')],
                labelColor: const Color(0xFFFF7A59),
                indicatorColor: const Color(0xFFFF7A59),
              ),
              Expanded(
                child: TabBarView(
                  children: [_loginForm(), _registerForm()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🧮', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 8),
          const Text('欢迎回来，快开始挑战吧！',
              style: TextStyle(fontSize: 18, color: Color(0xFF8A5A4A))),
          const SizedBox(height: 32),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(false),
          ),
          const SizedBox(height: 24),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return ElevatedButton(
                onPressed: state.isLoading ? null : () => _submit(false),
                child: Text(
                  state.isLoading ? '登录中…' : '登录',
                  style: const TextStyle(fontSize: 18),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            '演示账号：parent / 123456（家长）或 xiaoming / 123456（孩子）',
            style: TextStyle(fontSize: 12, color: Color(0xFFB09A8E)),
          ),
        ],
      ),
    );
  }

  Widget _registerForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('创建账号 ✨',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名（3-20 位字母、数字、下划线）',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码（至少 6 位）',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nickname,
            decoration: const InputDecoration(
              labelText: '昵称',
              prefixIcon: Icon(Icons.emoji_emotions_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('账号类型',
              style: TextStyle(fontSize: 14, color: Color(0xFF8A5A4A))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roleChip('孩子', 'child'),
              const SizedBox(width: 12),
              _roleChip('家长', 'parent'),
            ],
          ),
          const SizedBox(height: 16),
          if (_role == 'child') ...[
            const Text('选择年级',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A5A4A))),
            const SizedBox(height: 8),
            GradeChips(selected: _grade, onChanged: (g) => setState(() => _grade = g)),
          ],
          const SizedBox(height: 24),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return ElevatedButton(
                onPressed: state.isLoading ? null : () => _submit(true),
                child: Text(
                  state.isLoading ? '注册中…' : '注册',
                  style: const TextStyle(fontSize: 18),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            '家长注册后可在首页添加孩子账号并查看成绩',
            style: TextStyle(fontSize: 12, color: Color(0xFFB09A8E)),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String value) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4ECDC4) : const Color(0xFFE0F5F4),
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFBDE5E2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : const Color(0xFF3E7C77),
          ),
        ),
      ),
    );
  }
}
