import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/auth/token_store.dart';
import '../../../core/network/api_client.dart';

abstract class AuthService {
  Future<AuthSession?> restoreSession();

  Future<AuthSession?> refreshSession();

  Future<AuthSession> register({
    required String email,
    required String password,
    bool rememberSession = false,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberSession = false,
  });

  Future<void> signOut();
}

const _rememberSessionDuration = Duration(days: 1);
const _accessTokenRefreshSkew = Duration(minutes: 1);

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.capabilities,
    this.id,
    this.name,
    this.username,
    this.email,
    this.isActive = true,
  });

  final String accessToken;
  final String refreshToken;
  final int? id;
  final String? name;
  final String? username;
  final String? email;
  final String role;
  final bool isActive;
  final Map<String, bool> capabilities;

  bool get isPublicAccount => capabilities['public_account'] ?? false;
  bool get isAttendant =>
      capabilities['attendant'] ?? false || role == 'ATTENDANT';
  bool get isAdmin => capabilities['admin'] ?? false || role == 'ADMIN';

  factory AuthSession.fromAuthResponse(Map<String, dynamic> data) {
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    final user = data['user'];
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const AuthException('Thiếu token trong phản hồi xác thực.');
    }
    if (user is! Map<String, dynamic>) {
      throw const AuthException(
        'Thiếu thông tin người dùng trong phản hồi xác thực.',
      );
    }

    final capabilities = <String, bool>{};
    final rawCapabilities = user['capabilities'];
    if (rawCapabilities is Map<String, dynamic>) {
      for (final entry in rawCapabilities.entries) {
        capabilities[entry.key] = entry.value == true;
      }
    }

    final role = user['role'] as String?;
    if (role == null || role.isEmpty) {
      throw const AuthException(
        'Thiếu role của người dùng trong phản hồi xác thực.',
      );
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      id: user['id'] as int?,
      name: user['name'] as String?,
      username: user['username'] as String?,
      email: user['email'] as String?,
      role: role,
      isActive: user['is_active'] as bool? ?? true,
      capabilities: capabilities,
    );
  }

  factory AuthSession.fromStoredPayload({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
  }) {
    final decoded = jsonDecode(userPayload);
    if (decoded is! Map<String, dynamic>) {
      throw const AuthException('Dữ liệu phiên đăng nhập đã lưu không hợp lệ.');
    }
    return AuthSession.fromAuthResponse({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': decoded,
    });
  }

  String toStoredUserPayload() {
    return jsonEncode({
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'role': role,
      'is_active': isActive,
      'capabilities': capabilities,
    });
  }
}

class BackendAuthService implements AuthService {
  BackendAuthService({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) : _client = apiClient.client,
       _tokenStore = tokenStore;

  final Dio _client;
  final TokenStore _tokenStore;

  String get _connectionHelpMessage {
    final baseUrl = _client.options.baseUrl;
    return 'Khong ket noi duoc backend tai $baseUrl. Neu dang chay tren thiet bi that, hay them API_BASE_URL vao mobile/.env va dung adb reverse tcp:8000 tcp:8000 hoac mot host LAN phu hop.';
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final accessToken = await _tokenStore.readAccessToken();
    final refreshToken = await _tokenStore.readRefreshToken();
    final userPayload = await _tokenStore.readUserPayload();
    final rememberSession = await _tokenStore.readRememberSession();
    final sessionExpiresAt = await _tokenStore.readSessionExpiresAt();
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        userPayload == null ||
        userPayload.isEmpty) {
      return null;
    }

    if (!rememberSession ||
        sessionExpiresAt == null ||
        sessionExpiresAt.isEmpty ||
        _isRememberedSessionExpired(sessionExpiresAt)) {
      await _tokenStore.clear();
      return null;
    }

    var nextAccessToken = accessToken;
    if (_isAccessTokenExpiredOrNearExpiry(accessToken)) {
      try {
        nextAccessToken = await _refreshAccessToken(refreshToken);
        await _tokenStore.saveSession(
          accessToken: nextAccessToken,
          refreshToken: refreshToken,
          userPayload: userPayload,
          rememberSession: true,
          sessionExpiresAt: sessionExpiresAt,
        );
      } on AuthException {
        await _tokenStore.clear();
        return null;
      }
    }

    try {
      return AuthSession.fromStoredPayload(
        accessToken: nextAccessToken,
        refreshToken: refreshToken,
        userPayload: userPayload,
      );
    } on AuthException {
      await _tokenStore.clear();
      return null;
    }
  }

  @override
  Future<AuthSession?> refreshSession() async {
    final accessToken = await _tokenStore.readAccessToken();
    final refreshToken = await _tokenStore.readRefreshToken();
    final rememberSession = await _tokenStore.readRememberSession();
    final sessionExpiresAt = await _tokenStore.readSessionExpiresAt();

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    var nextAccessToken = accessToken;
    if (_isAccessTokenExpiredOrNearExpiry(accessToken)) {
      nextAccessToken = await _refreshAccessToken(refreshToken);
    }

    try {
      final response = await _client.get<dynamic>(
        '/auth/me',
        options: Options(
          headers: {'Authorization': 'Bearer $nextAccessToken'},
        ),
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw const AuthException('Phản hồi phiên hiện tại không hợp lệ.');
      }

      final user = responseData['user'];
      if (user is! Map<String, dynamic>) {
        throw const AuthException('Thiếu thông tin người dùng hiện tại.');
      }

      final session = AuthSession.fromAuthResponse({
        'access_token': nextAccessToken,
        'refresh_token': refreshToken,
        'user': user,
      });

      await _tokenStore.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        userPayload: session.toStoredUserPayload(),
        rememberSession: rememberSession,
        sessionExpiresAt: sessionExpiresAt,
      );
      return session;
    } on DioException catch (error) {
      if (error.response == null) {
        throw AuthException(_connectionHelpMessage);
      }
      throw const AuthException('Không thể đồng bộ phiên đăng nhập lúc này.');
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    bool rememberSession = false,
  }) async {
    final session = await _authenticate(
      path: '/auth/register',
      payload: {'email': email, 'password': password},
      rememberSession: rememberSession,
    );
    return session;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberSession = false,
  }) async {
    final session = await _authenticate(
      path: '/login',
      payload: {'username': email, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
      rememberSession: rememberSession,
    );
    return session;
  }

  Future<AuthSession> _authenticate({
    required String path,
    required Map<String, dynamic> payload,
    required bool rememberSession,
    Options? options,
  }) async {
    try {
      final response = await _client.post<dynamic>(
        path,
        data: payload,
        options: options,
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw const AuthException('Phản hồi xác thực không hợp lệ.');
      }

      final session = AuthSession.fromAuthResponse(responseData);
      final sessionExpiresAt = rememberSession
          ? DateTime.now()
                .toUtc()
                .add(_rememberSessionDuration)
                .toIso8601String()
          : null;
      await _tokenStore.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        userPayload: session.toStoredUserPayload(),
        rememberSession: rememberSession,
        sessionExpiresAt: sessionExpiresAt,
      );
      return session;
    } on DioException catch (error) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic> && payload['detail'] is String) {
        throw AuthException(payload['detail'] as String);
      }
      if (error.response == null) {
        throw AuthException(_connectionHelpMessage);
      }
      throw const AuthException('Không thể xác thực tài khoản lúc này.');
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

  bool _isRememberedSessionExpired(String sessionExpiresAt) {
    final expiry = DateTime.tryParse(sessionExpiresAt)?.toUtc();
    if (expiry == null) {
      return true;
    }
    return !expiry.isAfter(DateTime.now().toUtc());
  }

  bool _isAccessTokenExpiredOrNearExpiry(String token) {
    final payload = _decodeJwtPayload(token);
    final exp = payload['exp'];
    if (exp is! num) {
      return true;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
    return !expiresAt.isAfter(
      DateTime.now().toUtc().add(_accessTokenRefreshSkew),
    );
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final segments = token.split('.');
    if (segments.length != 3) {
      return const {};
    }

    try {
      final normalized = base64Url.normalize(segments[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
    } catch (_) {
      return const {};
    }

    return const {};
  }

  Future<String> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await _client.post<dynamic>(
        '/refresh',
        data: {'refresh_token': refreshToken},
      );
      final responseData = response.data;
      if (responseData is! Map<String, dynamic>) {
        throw const AuthException(
          'Phản hồi làm mới phiên đăng nhập không hợp lệ.',
        );
      }

      final accessToken = responseData['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw const AuthException(
          'Thiếu access token mới khi khôi phục phiên đăng nhập.',
        );
      }
      return accessToken;
    } on DioException catch (_) {
      throw const AuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
