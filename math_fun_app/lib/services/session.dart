import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/config.dart';
import '../models/models.dart';

/// 一个已记住的账号（用户名 + 昵称 + token），用于快速切换登录。
class SavedAccount {
  final String username;
  final String nickname;
  final String token;
  final Map<String, dynamic> userJson;

  const SavedAccount({
    required this.username,
    required this.nickname,
    required this.token,
    required this.userJson,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'nickname': nickname,
        'token': token,
        'userJson': userJson,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        username: (json['username'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
        token: (json['token'] ?? '').toString(),
        userJson: (json['userJson'] is Map)
            ? Map<String, dynamic>.from(json['userJson'] as Map)
            : <String, dynamic>{},
      );
}

/// 登录会话：token 与当前用户持久化到本地，并记住最近登录的多个账号。
class Session {
  static String? _token;
  static User? _user;
  static List<SavedAccount> _saved = [];

  static const _keyAccounts = 'saved_accounts';
  static const _maxAccounts = 8;

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  static User? get user => _user;
  static String? get token => _token;
  /// 记住的账号列表（最近使用的在前，不含当前账号由界面自行过滤）
  static List<SavedAccount> get savedAccounts => List.unmodifiable(_saved);

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
    // 读取记住的账号列表
    final accountsJson = prefs.getStringList(_keyAccounts) ?? <String>[];
    _saved = accountsJson
        .map((s) {
          try {
            return SavedAccount.fromJson(_decode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedAccount>()
        .toList();
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
    final uj = userJson(user);
    await prefs.setString('user', jsonEncode(uj));

    // 记住该账号：按用户名去重并置顶，超过上限丢弃最旧的
    final account = SavedAccount(
      username: user.username,
      nickname: user.nickname,
      token: token,
      userJson: uj,
    );
    _saved = [
      account,
      ..._saved.where((a) => a.username != user.username),
    ].take(_maxAccounts).toList();
    await _persistAccounts(prefs);
  }

  static Future<void> _persistAccounts(SharedPreferences prefs) async {
    await prefs.setStringList(
      _keyAccounts,
      _saved.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  /// 切换到某个已记住的账号（无需重新输入密码）。
  static Future<User?> switchTo(ApiClient client, SavedAccount account) async {
    if (account.token.isEmpty || account.userJson.isEmpty) return null;
    User? user;
    try {
      user = User.fromJson(account.userJson);
    } catch (_) {
      return null;
    }
    _token = account.token;
    _user = user;
    client.setToken(account.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', account.token);
    await prefs.setString('user', jsonEncode(account.userJson));

    // 将被切换的账号置顶
    _saved = [
      account,
      ..._saved.where((a) => a.username != account.username),
    ].take(_maxAccounts).toList();
    await _persistAccounts(prefs);
    return user;
  }

  static Map<String, dynamic> userJson(User user) {
    return {
      'id': user.id,
      'username': user.username,
      'nickname': user.nickname,
      'role': user.role,
      'grade': user.grade,
      'parentId': user.parentId,
      'points': user.points,
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
