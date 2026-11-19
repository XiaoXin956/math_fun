import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => 'ApiException($status, $message)';
}

/// 后端 API 客户端：统一 JSON 收发与 token 注入。
class ApiClient {
  final String baseUrl;

  ApiClient(this.baseUrl);

  String? _token;

  void setToken(String? token) => _token = token;

  Uri _uri(String path, Map<String, String>? query) {
    final map = query?.map((k, v) => MapEntry(Uri.encodeComponent(k), Uri.encodeComponent(v))) ??
        <String, String>{};
    return Uri.parse('$baseUrl$path').replace(queryParameters: map.isEmpty ? null : map);
  }

  Map<String, String> _headers() {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Future<Map<String, dynamic>> _request(
      http.ClientFunction func, String path,
      {Map<String, String>? query, Object? body}) async {
    final response = await func(_uri(path, query), headers: _headers(),
        body: body == null ? null : jsonEncode(body));
    final status = response.statusCode;
    final text = response.body ?? '';
    Map<String, dynamic> data = {};
    if (text.isNotEmpty) {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) data = decoded;
    }
    if (status < 200 || status >= 300) {
      throw ApiException(status, data['error'] as String? ?? '请求失败（$status）');
    }
    return data;
  }

  Future<Map<String, dynamic>> post(String path, Object? body) =>
      _request(http.post, path, body: body);

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _request(http.get, path, query: query);
}
