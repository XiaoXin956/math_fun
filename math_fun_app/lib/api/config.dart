/// 后端服务地址配置。
///
/// 默认为本地执行：后端与前端在同一台机器上运行时用 localhost。
/// 若后端部署在其它机器，改为后端所在机器的 IP，例如：
///   'http://192.168.1.10:8082'
/// 若在 Android 模拟器中运行，访问宿主机需改用 'http://10.0.2.2:8082'。
const String apiBaseUrl = 'http://localhost:8082';

/// 限时挑战的默认时长（秒）。
const int timedDurationSeconds = 60;
