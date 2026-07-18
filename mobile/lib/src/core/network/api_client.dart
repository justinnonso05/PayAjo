import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
