import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/env_config.dart';

/// Thrown for any non-2xx response or network failure, with a
/// user-presentable [message] extracted from the backend's error body
/// where possible.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Fires once, the first time any request comes back 401 — set at app
  /// startup to clear the stored token and bounce to login. Guarded so a
  /// burst of concurrent requests failing together (a common pattern right
  /// after expiry, since several screens refresh at once) only triggers it
  /// once instead of stacking redirects/toasts.
  static void Function()? onUnauthorized;
  static bool _isHandlingUnauthorized = false;

  static void resetUnauthorizedGuard() => _isHandlingUnauthorized = false;

  static void _handleUnauthorized() {
    if (_isHandlingUnauthorized) return;
    _isHandlingUnauthorized = true;
    onUnauthorized?.call();
  }

  static const _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    final uri = EnvConfig.uri(path);
    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {..._defaultHeaders, ...?headers})
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    } on Exception {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    }

    return _decode(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = EnvConfig.uri(path);
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {..._defaultHeaders, ...?headers},
            body: jsonEncode(body ?? const {}),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    } on Exception {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    }

    return _decode(response);
  }

  /// For the rare endpoint that returns a bare JSON array instead of the
  /// usual `{success, message, data}` envelope (e.g. chat history).
  Future<List<dynamic>> getList(String path, {Map<String, String>? headers}) async {
    final uri = EnvConfig.uri(path);
    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {..._defaultHeaders, ...?headers})
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    } on Exception {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return const [];
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : const [];
    }

    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Non-JSON body; fall through with an empty map.
    }
    if (response.statusCode == 401) {
      _handleUnauthorized();
    }
    throw ApiException(
      _extractErrorMessage(json) ?? 'Something went wrong (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final uri = EnvConfig.uri(path);
    late final http.Response response;
    try {
      response = await _client
          .patch(
            uri,
            headers: {..._defaultHeaders, ...?headers},
            body: jsonEncode(body ?? const {}),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    } on Exception {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    }

    return _decode(response);
  }

  /// Uploads a file as `multipart/form-data` — used for the avatar upload
  /// endpoint, which expects the raw bytes under the `file` field.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String filename,
    String fileFieldName = 'file',
    String? contentType,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    final uri = EnvConfig.uri(path);
    late final http.Response response;
    try {
      // Without an explicit contentType, MultipartFile.fromBytes defaults
      // to application/octet-stream — servers that validate the upload is
      // actually an image (e.g. FastAPI's UploadFile.content_type check)
      // reject that with "file is not an image".
      final resolvedContentType = contentType ?? _guessImageContentType(filename);
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({'Accept': 'application/json', ...?headers})
        ..fields.addAll(fields ?? const {})
        ..files.add(http.MultipartFile.fromBytes(
          fileFieldName,
          fileBytes,
          filename: filename,
          contentType: resolvedContentType != null ? MediaType.parse(resolvedContentType) : null,
        ));
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    } on Exception {
      throw ApiException('Unable to reach the server. Check your connection and try again.');
    }

    return _decode(response);
  }

  static String? _guessImageContentType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return null;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {
        // Non-JSON body; fall through with an empty map.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    if (response.statusCode == 401) {
      _handleUnauthorized();
    }

    throw ApiException(
      _extractErrorMessage(json) ?? 'Something went wrong (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  String? _extractErrorMessage(Map<String, dynamic> json) {
    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return first['msg'] as String;
      }
    }
    final message = json['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return null;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
