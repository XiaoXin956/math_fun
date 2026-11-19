import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => 'ApiException($status, $message)';
}

/// 后端 API 客户端：基于 Dio 的统一 JSON 收发与 token 注入。
/// 对外保持 post/get 两个方法，页面与 Cubit 的调用方式不变。
class ApiClient {
  final Dio _dio;

  ApiClient(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const <String, String>{
            'Content-Type': 'application/json; charset=utf-8',
          },
        ));

  String? _token;

  void setToken(String? token) => _token = token;

  Options _options() {
    final headers = <String, String>{};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return Options(headers: headers);
  }

  Map<String, dynamic> _handle(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return <String, dynamic>{};
  }

  ApiException _toException(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode ?? 0;
      String message = '请求失败（$status）';
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['error'] is String) {
        message = data['error'] as String;
      } else if (e.type == DioExceptionType.cancel) {
        message = '请求已取消';
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        message = '网络连接失败，请检查后端服务是否启动';
      }
      return ApiException(status, message);
    }
    return ApiException(0, '请求失败');
  }

  Future<Map<String, dynamic>> post(String path, Object? body) async {
    try {
      final response = await _dio.post(path, data: body, options: _options());
      return _handle(response);
    } catch (e) {
      throw _toException(e);
    }
  }

  Future<Map<String, dynamic>> get(
      String path, {Map<String, String>? query}) async {
    try {
      final response =
          await _dio.get(path, queryParameters: query, options: _options());
      return _handle(response);
    } catch (e) {
      throw _toException(e);
    }
  }
}
