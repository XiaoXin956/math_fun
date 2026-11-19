import 'dart:io';

/// 全局配置：优先读取进程环境变量，其次读取 .env 文件，最后使用默认值。
///
/// 优先级：系统环境变量 > .env 文件 > 代码默认值。
/// .env 文件查找顺序（取第一个存在的）：
///   1. 当前工作目录下的 .env
///   2. 当前工作目录下的 math_fun_service/.env
///   3. 脚本文件所在目录及其上一级目录下的 .env
/// 这样无论从项目根目录还是 math_fun_service 目录启动，都能加载到配置。
class AppConfig {
  final String host;
  final int port;
  final String dbHost;
  final int dbPort;
  final String dbUser;
  final String dbPassword;
  final String dbName;
  final bool dbSecure;
  final int tokenTtlDays;

  const AppConfig({
    required this.host,
    required this.port,
    required this.dbHost,
    required this.dbPort,
    required this.dbUser,
    required this.dbPassword,
    required this.dbName,
    required this.dbSecure,
    required this.tokenTtlDays,
  });

  /// 解析 .env 文件为键值对（忽略空行与 # 注释，支持 KEY=VALUE 与 export KEY=VALUE）。
  static Map<String, String> _parseEnvFile(File file) {
    final result = <String, String>{};
    for (var line in file.readAsLinesSync()) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('export ')) line = line.substring(7).trim();
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      var value = line.substring(eq + 1).trim();
      // 去掉成对的单/双引号
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
    return result;
  }

  /// 依次查找候选路径，返回第一个存在的 .env 内容；都找不到则返回空 Map。
  static Map<String, String> _loadEnvFile() {
    final candidates = <String>['.env', 'math_fun_service${Platform.pathSeparator}.env'];
    try {
      final script = File.fromUri(Platform.script).absolute.path;
      final dir = File(script).parent.path;
      candidates.addAll([
        '$dir${Platform.pathSeparator}.env',
        '$dir${Platform.pathSeparator}..${Platform.pathSeparator}.env',
        '$dir${Platform.pathSeparator}..${Platform.pathSeparator}math_fun_service${Platform.pathSeparator}.env',
      ]);
    } catch (_) {
      // Platform.script 在编译后的 exe 中可能不可用，忽略即可
    }
    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) return _parseEnvFile(file);
    }
    return <String, String>{};
  }

  static String _env(
    String key,
    String fallback,
    Map<String, String> fileEnv,
  ) {
    // 1) 系统环境变量优先
    final sys = Platform.environment[key];
    if (sys != null && sys.trim().isNotEmpty) return sys.trim();
    // 2) .env 文件
    final fileValue = fileEnv[key];
    if (fileValue != null && fileValue.trim().isNotEmpty) return fileValue.trim();
    // 3) 默认值
    return fallback;
  }

  static AppConfig fromEnv() {
    final fileEnv = _loadEnvFile();
    return AppConfig(
      host: _env('HOST', '0.0.0.0', fileEnv),
      port: int.tryParse(_env('PORT', '8080', fileEnv)) ?? 8080,
      dbHost: _env('DB_HOST', '127.0.0.1', fileEnv),
      dbPort: int.tryParse(_env('DB_PORT', '3306', fileEnv)) ?? 3306,
      dbUser: _env('DB_USER', 'root', fileEnv),
      dbPassword: _env('DB_PASSWORD', '123456', fileEnv),
      dbName: _env('DB_NAME', 'math_fun', fileEnv),
      dbSecure: _env('DB_SECURE', 'false', fileEnv).toLowerCase() == 'true',
      tokenTtlDays: int.tryParse(_env('TOKEN_TTL_DAYS', '7', fileEnv)) ?? 7,
    );
  }
}
