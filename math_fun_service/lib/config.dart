import 'dart:io';

/// 全局配置：优先读取环境变量，方便 Docker 部署时注入。
class AppConfig {
  final String host;
  final int port;
  final String dbHost;
  final int dbPort;
  final String dbUser;
  final String dbPassword;
  final String dbName;
  final int tokenTtlDays;

  const AppConfig({
    required this.host,
    required this.port,
    required this.dbHost,
    required this.dbPort,
    required this.dbUser,
    required this.dbPassword,
    required this.dbName,
    required this.tokenTtlDays,
  });

  static String _env(String key, String fallback) =>
      Platform.environment[key]?.trim().isNotEmpty == true
          ? Platform.environment[key]!.trim()
          : fallback;

  static AppConfig fromEnv() {
    return AppConfig(
      host: _env('HOST', '0.0.0.0'),
      port: int.tryParse(_env('PORT', '8080')) ?? 8080,
      dbHost: _env('DB_HOST', '127.0.0.1'),
      dbPort: int.tryParse(_env('DB_PORT', '3306')) ?? 3306,
      dbUser: _env('DB_USER', 'root'),
      dbPassword: _env('DB_PASSWORD', '123456'),
      dbName: _env('DB_NAME', 'math_fun'),
      tokenTtlDays: int.tryParse(_env('TOKEN_TTL_DAYS', '7')) ?? 7,
    );
  }
}
