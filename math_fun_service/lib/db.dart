import 'package:mysql_client/mysql_client.dart';

import 'config.dart';

/// MySQL 连接池与建表逻辑，基于 mysql_client 的 MySQLConnectionPool。
/// 启动时自动执行幂等的 CREATE TABLE IF NOT EXISTS，无需手动建库建表。
class Db {
  static MySQLConnectionPool? _pool;
  static AppConfig? _config;

  static AppConfig get config => _config!;

  static MySQLConnectionPool get pool => _pool!;

  static Future<void>  init(AppConfig config) async {
    _config = config;

    // 重试等待 MySQL 就绪（例如 docker-compose 中数据库还在初始化）
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (true) {
      try {
        _pool = MySQLConnectionPool(
          host: config.dbHost,
          port: config.dbPort,
          userName: config.dbUser,
          password: config.dbPassword,
          databaseName: config.dbName,
          maxConnections: 8,
          // 是否启用 TLS：由 DB_SECURE 配置决定。
          // 远程 MySQL（caching_sha2_password 认证）必须启用，
          // 本地 Docker 内网库无需启用。
          secure: config.dbSecure,
          collation: 'utf8mb4_unicode_ci',
        );
        await _pool!.execute('SELECT 1');
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

  /// 在连接池中执行一段数据库操作（mysql_client 池自动归还连接）。
  static Future<T> withConn<T>(Future<T> Function(MySQLConnection conn) fn) async {
    return _pool!.withConnection(fn);
  }

  static Future<void> _createSchema() async {
    final pool = _pool!;

    await pool.execute('CREATE TABLE IF NOT EXISTS users ('
        'id INT AUTO_INCREMENT PRIMARY KEY,'
        'username VARCHAR(32) NOT NULL UNIQUE,'
        'password_hash VARCHAR(128) NOT NULL,'
        'salt VARCHAR(32) NOT NULL,'
        'nickname VARCHAR(32) NOT NULL,'
        "role ENUM('parent','child') NOT NULL DEFAULT 'child',"
        'grade TINYINT NULL,'
        'parent_id INT NULL,'
        'points INT NOT NULL DEFAULT 0,'
        'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    await pool.execute('CREATE TABLE IF NOT EXISTS sessions ('
        'token VARCHAR(64) PRIMARY KEY,'
        'user_id INT NOT NULL,'
        'expires_at DATETIME NOT NULL,'
        'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,'
        'INDEX idx_user (user_id)'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    await pool.execute('CREATE TABLE IF NOT EXISTS questions ('
        'id VARCHAR(64) PRIMARY KEY,'
        'expression VARCHAR(64) NOT NULL,'
        'answer INT NOT NULL,'
        'grade TINYINT NOT NULL,'
        "type VARCHAR(20) NOT NULL DEFAULT 'math',"
        'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    await pool.execute('CREATE TABLE IF NOT EXISTS records ('
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

    await pool.execute('CREATE TABLE IF NOT EXISTS challenge_progress ('
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

    await pool.execute('CREATE TABLE IF NOT EXISTS timed_best ('
        'id INT AUTO_INCREMENT PRIMARY KEY,'
        'user_id INT NOT NULL,'
        'grade TINYINT NOT NULL,'
        'best_score INT NOT NULL DEFAULT 0,'
        'best_correct INT NOT NULL DEFAULT 0,'
        'played_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        ' ON UPDATE CURRENT_TIMESTAMP,'
        'UNIQUE KEY uniq_user_grade (user_id, grade)'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    // 积分记录表
    await pool.execute('CREATE TABLE IF NOT EXISTS points_records ('
        'id INT AUTO_INCREMENT PRIMARY KEY,'
        'user_id INT NOT NULL,'
        'grade TINYINT NOT NULL DEFAULT 0,'
        'level TINYINT NOT NULL DEFAULT 0,'
        '`change` INT NOT NULL,'
        'reason VARCHAR(128) NOT NULL,'
        'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,'
        'INDEX idx_user_time (user_id, created_at),'
        'INDEX idx_user_level (user_id, grade, level)'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    // 自由练习每日次数统计（每天每用户一行，用于限制每日加分次数）
    await pool.execute('CREATE TABLE IF NOT EXISTS practice_daily ('
        'id INT AUTO_INCREMENT PRIMARY KEY,'
        'user_id INT NOT NULL,'
        'practice_date DATE NOT NULL,'
        'rounds INT NOT NULL DEFAULT 0,'
        'UNIQUE KEY uniq_user_date (user_id, practice_date)'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    // 手写答案提交表（等待家长批改）
    await pool.execute('CREATE TABLE IF NOT EXISTS handwriting_submissions ('
        'id INT AUTO_INCREMENT PRIMARY KEY,'
        'user_id INT NOT NULL,'
        'batch_id VARCHAR(64) NOT NULL DEFAULT "",'
        'question_id VARCHAR(64) NOT NULL,'
        'expression VARCHAR(64) NOT NULL,'
        'answer INT NOT NULL,'
        'image LONGTEXT NOT NULL,'
        'status ENUM("pending","reviewed") NOT NULL DEFAULT "pending",'
        'reviewed_by INT NULL,'
        'review_change INT NULL,'
        'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,'
        'reviewed_at DATETIME NULL,'
        'INDEX idx_user (user_id),'
        'INDEX idx_status (status),'
        'INDEX idx_batch (batch_id)'
        ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');

    // 兼容旧库：补充后来新增的字段（新库建表时已包含，重复执行报错则忽略）
    try {
      await pool.execute('ALTER TABLE users ADD COLUMN points INT NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await pool.execute(
          "ALTER TABLE questions ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'math'");
    } catch (_) {}
    // 手写提交表增加批次号（旧库兼容：空串表示无批次的历史记录）
    try {
      await pool.execute(
          'ALTER TABLE handwriting_submissions ADD COLUMN batch_id VARCHAR(64) NOT NULL DEFAULT "" AFTER user_id');
    } catch (_) {}
    try {
      await pool.execute(
          'ALTER TABLE handwriting_submissions ADD INDEX idx_batch (batch_id)');
    } catch (_) {}

    // 清理过期题目（7 天前的临时题目记录）
    await pool.execute(
        "DELETE FROM questions WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)");
  }
}
