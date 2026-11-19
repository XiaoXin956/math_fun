import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mysql_client/mysql_client.dart';

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

/// users 表查询结果（typedAssoc 转 Map 后）转成前端使用的用户对象。
/// 键: id, username, nickname, role, grade, parent_id, points
Map<String, dynamic> userMap(Map<String, dynamic> row) {
  return {
    'id': row['id'],
    'username': row['username'],
    'nickname': row['nickname'],
    'role': row['role'],
    'grade': row['grade'],
    'parentId': row['parent_id'],
    'points': row['points'],
  };
}

/// 校验请求头中的 Bearer token，返回当前登录用户信息。
/// 未登录或 token 过期时抛出 401 ApiError。
Future<Map<String, dynamic>> requireUser(Map<String, List<String>> headers) async {
  final auth = headers['authorization']?.first ?? '';
  final token = auth.startsWith('Bearer ') ? auth.substring(7).trim() : '';
  if (token.isEmpty) {
    throw const ApiError(401, '请先登录');
  }
  final rows = await Db.withConn((conn) async {
    final res = await conn.execute(
        'SELECT u.id, u.username, u.nickname, u.role, u.grade, u.parent_id, u.points '
        'FROM sessions s JOIN users u ON u.id = s.user_id '
        'WHERE s.token = :token AND s.expires_at > NOW()',
        {'token': token});
    return res.rows;
  });
  if (rows.isEmpty) {
    throw const ApiError(401, '登录已过期，请重新登录');
  }
  return userMap(rows.first.typedAssoc());
}

/// 创建登录会话，返回新 token。
Future<String> createSession(int userId) async {
  final token = newToken();
  await Db.withConn((conn) async {
    await conn.execute(
        'INSERT INTO sessions (token, user_id, expires_at) '
        'VALUES (:token, :uid, DATE_ADD(NOW(), INTERVAL :days DAY))',
        {'token': token, 'uid': userId, 'days': Db.config.tokenTtlDays});
  });
  return token;
}
