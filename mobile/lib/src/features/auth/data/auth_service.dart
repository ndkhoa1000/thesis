import 'package:dio/dio.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/network/api_client.dart';

abstract class AuthService {
  Future<bool> hasSession();

  Future<void> register({required String email, required String password});

  Future<void> signOut();
}

class BackendAuthService implements AuthService {
  BackendAuthService({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) : _client = apiClient.client,
       _tokenStore = tokenStore;

  final Dio _client;
  final TokenStore _tokenStore;

  @override
  Future<bool> hasSession() async {
    final accessToken = await _tokenStore.readAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post<dynamic>(
        '/auth/register',
        data: {'email': email, 'password': password},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Phản hồi đăng ký không hợp lệ.');
      }

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        throw const AuthException('Thiếu token sau khi đăng ký thành công.');
      }

      await _tokenStore.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (error) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic> && payload['detail'] is String) {
        throw AuthException(payload['detail'] as String);
      }
      throw const AuthException('Không thể đăng ký tài khoản lúc này.');
    }
  }

  @override
  Future<void> signOut() async {
    final accessToken = await _tokenStore.readAccessToken();
    final refreshToken = await _tokenStore.readRefreshToken();

    try {
      if (accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty) {
        await _client.post<dynamic>(
          '/logout',
          data: {'refresh_token': refreshToken},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      }
    } finally {
      await _tokenStore.clear();
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
