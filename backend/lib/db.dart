import 'package:mysql2/mysql2.dart';

import 'config.dart';

/// MySQL 连接池 + 建表逻辑。
/// 启动时自动执行幂等的 CREATE TABLE IF NOT EXISTS，无需手动建库建表。
class Db {
  static const int _maxConnections = 8;
  static List<MySqlConnection> _free = [];
  static int _created = 0;
  static AppConfig? _config;

  static AppConfig get config => _config!;

  static Future<void> init(AppConfig config) async {
    _config = config;

    // 重试等待 MySQL 就绪（例如 docker-compose 中数据库还在初始化）
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (true) {
      try {
        final conn = await _create();
        await conn.query('SELECT 1');
        await conn.close();
        break;
      } catch (e) {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('无法连接 MySQL: $e');
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    await _createSchema();
  }

  static MySqlConnection _create() => MySqlConnection.connect(
        MySQLConnectionSettings(
          host: config.dbHost,
          port: config.dbPort,
          user: config.dbUser,
          password: config.dbPassword,
          database: config.dbName,
        ),
      );

  static Future<MySqlConnection> _acquire() async {
    if (_free.isNotEmpty) {
      return _free.removeLast();
    }
    if (_created < _maxConnections) {
      _created++;
      return _create();
    }
    // 连接池打满时等待其它请求归还（简单轮询）
    while (_free.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return _free.removeLast();
  }

  static void _release(MySqlConnection conn) {
    if (_free.length < _maxConnections) {
      _free.add(conn);
    } else {
      conn.close();
    }
  }

  /// 在连接池中执行一段数据库操作，用完自动归还。
  static Future<T> withConn<T>(Future<T> Function(MySqlConnection conn) fn) async {
    final conn = await _acquire();
    var broken = false;
    try {
      return await fn(conn);
    } catch (e) {
      // 连接可能已失效，丢弃重建
      broken = true;
      _created--;
      conn.close();
      rethrow;
    } finally {
      if (!broken) {
        _release(conn);
      }
    }
  }

  static Future<void> _createSchema() async {
    await withConn((conn) async {
      await conn.query('CREATE TABLE IF NOT EXISTS users ('
          'id INT AUTO_INCREMENT PRIMARY KEY,'
          'username VARCHAR(32) NOT NULL UNIQUE,'
          'password_hash VARCHAR(128) NOT NULL,'
          'salt VARCHAR(32) NOT NULL,'
          'nickname VARCHAR(32) NOT NULL,'
          "role ENUM('parent','child') NOT NULL DEFAULT 'child',"
          'grade TINYINT NULL,'
          'parent_id INT NULL,'
          'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

      await conn.query('CREATE TABLE IF NOT EXISTS sessions ('
          'token VARCHAR(64) PRIMARY KEY,'
          'user_id INT NOT NULL,'
          'expires_at DATETIME NOT NULL,'
          'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,'
          'INDEX idx_user (user_id)'
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

      await conn.query('CREATE TABLE IF NOT EXISTS questions ('
          'id VARCHAR(64) PRIMARY KEY,'
          'expression VARCHAR(64) NOT NULL,'
          'answer INT NOT NULL,'
          'grade TINYINT NOT NULL,'
          'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

      await conn.query('CREATE TABLE IF NOT EXISTS records ('
          'id INT AUTO_INCREMENT PRIMARY KEY,'
          'user_id INT NOT NULL,'
          'question_id VARCHAR(64) NOT NULL,'
          'expression VARCHAR(64) NOT NULL,'
          'answer INT NOT NULL,'
          'user_answer INT NOT NULL,'
          'correct TINYINT NOT NULL DEFAULT 0,'
          "mode VARCHAR(20) NOT NULL DEFAULT 'practice',"
          'grade TINYINT NOT NULL,'
          'duration_ms INT NOT NULL DEFAULT 0,'
          'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,'
          'INDEX idx_user_time (user_id, created_at)'
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

      await conn.query('CREATE TABLE IF NOT EXISTS challenge_progress ('
          'id INT AUTO_INCREMENT PRIMARY KEY,'
          'user_id INT NOT NULL,'
          'grade TINYINT NOT NULL,'
          'level TINYINT NOT NULL,'
          'best_correct INT NOT NULL DEFAULT 0,'
          'best_total INT NOT NULL DEFAULT 0,'
          'best_stars TINYINT NOT NULL DEFAULT 0,'
          'updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
          ' ON UPDATE CURRENT_TIMESTAMP,'
          'UNIQUE KEY uniq_user_grade_level (user_id, grade, level)'
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

      await conn.query('CREATE TABLE IF NOT EXISTS timed_best ('
          'id INT AUTO_INCREMENT PRIMARY KEY,'
          'user_id INT NOT NULL,'
          'grade TINYINT NOT NULL,'
          'best_score INT NOT NULL DEFAULT 0,'
          'best_correct INT NOT NULL DEFAULT 0,'
          'played_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
          ' ON UPDATE CURRENT_TIMESTAMP,'
          'UNIQUE KEY uniq_user_grade (user_id, grade)'
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

      // 清理过期题目（7 天前的临时题目记录）
      await conn.query(
          "DELETE FROM questions WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)");
    });
  }
}
