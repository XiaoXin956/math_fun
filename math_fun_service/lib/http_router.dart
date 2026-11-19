import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 轻量 HTTP 路由：基于 dart:io 的 HttpServer，支持 /path/:param 形式的路径参数。
/// 统一 JSON 收发、CORS、错误处理。

class ApiError extends Exception {
  final int status;
  final String message;
  const ApiError(this.status, this.message);

  @override
  String toString() => 'ApiError($status, $message)';
}

class RouteContext {
  final HttpRequest request;
  final Map<String, String> params;
  final Map<String, dynamic> query;
  final Map<String, dynamic> body;

  RouteContext(
    this.request,
    this.params,
    this.query,
    this.body,
  );

  String header(String name) => request.headers[name] ?? '';
}

typedef Handler = Future<dynamic> Function(RouteContext ctx);

class _RouteEntry {
  final List<String> segments;
  final Handler handler;
  const _RouteEntry(this.segments, this.handler);
}

class Router {
  final String host;
  final int port;
  final Map<String, Map<String, _RouteEntry>> _routes = {};
  HttpServer? _server;

  Router({required this.host, required this.port});

  void add(String method, String pattern, Handler handler) {
    final segments = pattern
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    _routes.putIfAbsent(method.toUpperCase(), () => {});
    _routes[method.toUpperCase()]![pattern] = _RouteEntry(segments, handler);
  }

  Future<void> start() async {
    _server = await HttpServer.bind(host, port);
    await for (final request in _server!) {
      _handle(request);
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final response = await _dispatch(request);
      final bytes = jsonEncode(response);
      final res = request.response;
      res.headers.contentType = ContentType.json;
      res.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
      res.headers.set(
          HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type, Authorization');
      res.headers.set(HttpHeaders.accessControlAllowMethodsHeader,
          'GET, POST, PUT, DELETE, OPTIONS');
      await res.add(utf8.encode(bytes));
      await res.close();
    } catch (e) {
      await _sendError(request, e);
    }
  }

  Future<void> _sendError(HttpRequest request, Object e) async {
    int status = 500;
    String message = '服务器内部错误';
    if (e is ApiError) {
      status = e.status;
      message = e.message;
    } else {
      // 未预期异常打印到日志，便于排查
      // ignore: avoid_print
      print('[server error] $e');
    }
    try {
      final res = request.response;
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      res.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
      await res.add(utf8.encode(jsonEncode({'error': message})));
      await res.close();
    } catch (_) {
      // 响应已发出或连接已断开，忽略
    }
  }

  Future<dynamic> _dispatch(HttpRequest request) async {
    final method = request.method.toUpperCase();
    final uri = Uri.parse(request.uri.toString());

    if (method == 'OPTIONS') {
      return {'ok': true};
    }

    final segments = uri.path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final routeMap = _routes[method];
    if (routeMap == null) {
      throw ApiError(404, '接口不存在');
    }

    final entry = routeMap.values.firstWhere(
      (e) => _match(e.segments, segments),
      orElse: () => null,
    );
    if (entry == null) {
      throw ApiError(404, '接口不存在');
    }

    final params = <String, String>{};
    for (var i = 0; i < entry.segments.length; i++) {
      final seg = entry.segments[i];
      if (seg.startsWith(':')) {
        params[seg.substring(1)] = segments[i];
      }
    }

    final body = <String, dynamic>{};
    if (method == 'POST' || method == 'PUT') {
      final raw = await utf8.decode(await request.fold(<List<int>>[],
          (acc, bytes) => acc..addAll(bytes)));
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          body.addAll(decoded);
        }
      }
    }

    return entry.handler(
      RouteContext(request, params, uri.queryParameters, body),
    );
  }

  bool _match(List<String> pattern, List<String> actual) {
    if (pattern.length != actual.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      final p = pattern[i];
      if (p.startsWith(':')) continue;
      if (p != actual[i]) return false;
    }
    return true;
  }
}
