import 'package:bloc/bloc.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session.dart';

/// 认证与会话状态：登录、注册、退出、从本地会话恢复、刷新用户（含积分）。
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copy({User? user, bool? isLoading, String? error}) {
    return AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error);
  }
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  ApiClient get _client => Session.createClient();

  /// 应用启动时从本地存储恢复登录会话。
  Future<void> init() async {
    await Session.init();
    final token = Session.token;
    if (token == null || token.isEmpty) return;
    try {
      final res = await _client.get('/api/auth/me');
      if (res['user'] != null) {
        emit(AuthState(user: User.fromJson(res['user'] as Map<String, dynamic>)));
      }
    } catch (_) {
      // token 失效，保持未登录状态
    }
  }

  Future<void> login(String username, String password) async {
    emit(const AuthState(isLoading: true));
    try {
      final res = await _client.post('/api/auth/login',
          {'username': username, 'password': password});
      await _saveUser(res);
    } catch (e) {
      emit(AuthState(error: e is ApiException ? e.message : '请求失败，请检查后端服务'));
    }
  }

  Future<void> register(Map<String, dynamic> body) async {
    emit(const AuthState(isLoading: true));
    try {
      final res = await _client.post('/api/auth/register', body);
      await _saveUser(res);
    } catch (e) {
      emit(AuthState(error: e is ApiException ? e.message : '请求失败，请检查后端服务'));
    }
  }

  Future<void> _saveUser(Map<String, dynamic> res) async {
    final user = User.fromJson(res['user'] as Map<String, dynamic>);
    final token = res['token'] as String;
    await Session.save(_client, user, token);
    emit(AuthState(user: user));
  }

  /// 退出登录：通知服务端并清空本地会话。
  Future<void> logout() async {
    try {
      await _client.post('/api/auth/logout', {});
    } catch (_) {
      // 忽略登出请求失败
    }
    await Session.clear();
    emit(const AuthState());
  }

  /// 重新拉取当前用户（积分变动后调用，让首页等同步更新）。
  Future<void> refresh() async {
    final current = state.user;
    if (current == null) return;
    try {
      final res = await _client.get('/api/auth/me');
      final user = User.fromJson(res['user'] as Map<String, dynamic>);
      emit(AuthState(user: user));
    } catch (_) {
      // 保持原状态
    }
  }
}
