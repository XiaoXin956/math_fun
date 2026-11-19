import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mysql2/mysql2.dart';

import 'db.dart';
import 'http_router.dart';

/// 密码哈希与登录令牌（token）工具。
/// 密码存储格式：sha256(salt + password) 的十六进制字符串。

String _sha256Hex(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

String hashPassword(String salt, String password) {
  return _sha256Hex('$salt$password');
}

String newSalt() {
  final buf = List<int>.filled(8, 0);
  Random.secure().nextBytes(buf);
  return buf.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String newToken() {
  final buf = List<int>.filled(32, 0);
  Random.secure().nextBytes(buf);
  return buf.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String newQuestionId() {
  final buf = List<int>.filled(16, 0);
  Random.secure().nextBytes(buf);
  return buf.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// users 表查询结果（按固定列序）转成前端使用的用户对象。
/// 列序: id, username, nickname, role, grade, parent_id, points
Map<String, dynamic> userMap(MySqlRow row) {
  return {
    'id': row[0],
    'username': row[1],
    'nickname': row[2],
    'role': row[3],
    'grade': row[4],
    'parentId': row[5],
    'points': row[6],
  };
}

/// 校验请求头中的 Bearer token，返回当前登录用户信息。
/// 未登录或 token 过期时抛出 401 ApiError。
Future<Map<String, dynamic>> requireUser(Map<String, String> headers) async {
  final auth = headers['authorization'] ?? '';
  final token = auth.startsWith('Bearer ') ? auth.substring(7).trim() : '';
  if (token.isEmpty) {
    throw const ApiError(401, '请先登录');
  }
  final rows = await Db.withConn((conn) async {
    final res = await conn.query(
        'SELECT u.id, u.username, u.nickname, u.role, u.grade, u.parent_id, u.points '
        'FROM sessions s JOIN users u ON u.id = s.user_id '
        'WHERE s.token = ? AND s.expires_at > NOW()',
        [token]);
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(401, '登录已过期，请重新登录');
  }
  return userMap(rows.first);
}

/// 创建登录会话，返回新 token。
Future<String> createSession(int userId) async {
  final token = newToken();
  final expires =
      DateTime.now().add(Duration(days: Db.config.tokenTtlDays));
  await Db.withConn((conn) async {
    await conn.query(
        'INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)',
        [token, userId, expires]);
  });
  return token;
}
