/// 后端服务地址配置。
///
/// 默认值供手机 App / 本地调试使用：直连后端绝对地址。
/// Web 部署时由 Dockerfile.web 通过 --dart-define=API_BASE_URL= 覆盖为空，
/// 走浏览器同源的 /api 路径，由 nginx 反代到后端容器（无需跨域）。
///
/// 手动构建其它环境示例：
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8082   # Android 模拟器
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8082  # 局域网真机
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://47.250.81.247:8082',
);

/// 限时挑战的默认时长（秒）。
const int timedDurationSeconds = 60;
