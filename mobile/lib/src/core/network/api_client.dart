import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _resolveBaseUrl(baseUrl),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
              headers: const {'Content-Type': 'application/json'},
            ),
          );

  static String _resolveBaseUrl(String? override) {
    final configured = override ?? dotenv.env['API_BASE_URL'];
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }

    // Android emulator can reach the host machine through 10.0.2.2.
    return 'http://10.0.2.2:8000/api/v1';
  }

  final Dio _dio;

  Dio get client => _dio;
}
