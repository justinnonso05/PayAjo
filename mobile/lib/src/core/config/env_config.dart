import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnvConfig {
  static const String defaultBaseUrl = 'https://payajo.fastapicloud.dev';

  /// Returns the configured Base URL.
  /// Precedence:
  /// 1. `.env` file key `BASE_URL` (loaded via flutter_dotenv)
  /// 2. `--dart-define=BASE_URL=...` compile-time flag
  /// 3. Default fallback: `https://payajo.fastapicloud.dev`
  static String get baseUrl {
    try {
      final envUrl = dotenv.env['BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) {
        return envUrl;
      }
    } catch (_) {
      // dotenv not loaded yet or unavailable
    }

    const compileTimeUrl = String.fromEnvironment('BASE_URL');
    if (compileTimeUrl.isNotEmpty) {
      return compileTimeUrl;
    }

    return defaultBaseUrl;
  }

  /// Helper utility to build full URI endpoints
  static Uri uri(String endpointPath) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = endpointPath.startsWith('/')
        ? endpointPath
        : '/$endpointPath';
    return Uri.parse('$cleanBase$cleanPath');
  }

  /// Same as [uri], but with the scheme swapped for its WebSocket
  /// equivalent (https -> wss, http -> ws).
  static Uri wsUri(String endpointPath) {
    final httpUri = uri(endpointPath);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: wsScheme);
  }
}

/// Riverpod provider for accessing the API base URL
final baseUrlProvider = Provider<String>((ref) {
  return EnvConfig.baseUrl;
});
