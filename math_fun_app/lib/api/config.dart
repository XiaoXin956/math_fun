/// 后端服务地址配置。
///
/// 默认值供手机 App / 本地调试使用：直连后端绝对地址。
/// Web 部署时由 Dockerfile.web 通过 --dart-define=API_BASE_URL= 覆盖为空，
/// 走浏览器同源的 /api 路径，由 nginx 反代到后端容器（无需跨域）。
///
/// 默认指向本地 debug 后端（IDE 里 dart run，监听 9001）。
/// 线上 release 后端走 8082，由部署环境通过 --dart-define 覆盖此值。
///
/// 手动构建其它环境示例：
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9001   # Android 模拟器访问宿主机
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:9001  # 局域网真机
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:9001',
);

/// 限时挑战的默认时长（秒）。
const int timedDurationSeconds = 60;
