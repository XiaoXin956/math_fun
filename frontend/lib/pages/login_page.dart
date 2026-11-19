import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'home_page.dart';

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

  String _role = 'child'; // child / parent
  int _grade = 2;

  ApiClient get _client => Session.createClient();

  Future<void> _submit(bool isRegister) async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      _error('请输入用户名和密码');
      return;
    }
    try {
      final res = await _client.post(
        isRegister ? '/api/auth/register' : '/api/auth/login',
        isRegister
            ? {
                'username': username,
                'password': password,
                'nickname': _nickname.text.trim(),
                'role': _role,
                'grade': _role == 'child' ? _grade : null,
              }
            : {'username': username, 'password': password},
      );
      final user = User.fromJson(res['user'] as Map<String, dynamic>);
      await Session.save(_client, user, res['token'] as String);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(HomePage.routeName);
    } catch (e) {
      if (!mounted) return;
      _error(e is ApiException ? e.message : '请求失败，请检查后端服务是否启动');
    }
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

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
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
          ElevatedButton(onPressed: () => _submit(false), child: const Text('登录')),
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
          ElevatedButton(onPressed: () => _submit(true), child: const Text('注册')),
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
