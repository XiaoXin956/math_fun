import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../models/models.dart';

/// 登录会话：token 与当前用户持久化到本地。
class Session {
  static String? _token;
  static User? _user;

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  static User? get user => _user;
  static String? get token => _token;

  static ApiClient createClient() {
    final client = ApiClient(apiBaseUrl);
    client.setToken(_token);
    return client;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        _user = User.fromJson(_decode(userJson));
      } catch (_) {
        _user = null;
      }
    }
  }

  static Map<String, dynamic> _decode(String s) {
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> save(ApiClient client, User user, String token) async {
    _token = token;
    _user = user;
    client.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(userJson(user)));
  }

  static Map<String, dynamic> userJson(User user) {
    return {
      'id': user.id,
      'username': user.username,
      'nickname': user.nickname,
      'role': user.role,
      'grade': user.grade,
      'parentId': user.parentId,
    };
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }
}
