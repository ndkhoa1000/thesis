import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<String?> readUserPayload();

  Future<bool> readRememberSession();

  Future<String?> readSessionExpiresAt();

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
    required bool rememberSession,
    String? sessionExpiresAt,
  });

  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userPayloadKey = 'user_payload';
  static const _rememberSessionKey = 'remember_session';
  static const _sessionExpiresAtKey = 'session_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userPayloadKey);
    await _storage.delete(key: _rememberSessionKey);
    await _storage.delete(key: _sessionExpiresAtKey);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<String?> readUserPayload() {
    return _storage.read(key: _userPayloadKey);
  }

  @override
  Future<bool> readRememberSession() async {
    return (await _storage.read(key: _rememberSessionKey)) == 'true';
  }

  @override
  Future<String?> readSessionExpiresAt() {
    return _storage.read(key: _sessionExpiresAtKey);
  }

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
    required bool rememberSession,
    String? sessionExpiresAt,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userPayloadKey, value: userPayload);
    await _storage.write(
      key: _rememberSessionKey,
      value: rememberSession ? 'true' : 'false',
    );
    if (sessionExpiresAt == null || sessionExpiresAt.isEmpty) {
      await _storage.delete(key: _sessionExpiresAtKey);
    } else {
      await _storage.write(key: _sessionExpiresAtKey, value: sessionExpiresAt);
    }
  }
}

class MemoryTokenStore implements TokenStore {
  String? _accessToken;
  String? _refreshToken;
  String? _userPayload;
  bool _rememberSession = false;
  String? _sessionExpiresAt;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _userPayload = null;
    _rememberSession = false;
    _sessionExpiresAt = null;
  }

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<String?> readUserPayload() async => _userPayload;

  @override
  Future<bool> readRememberSession() async => _rememberSession;

  @override
  Future<String?> readSessionExpiresAt() async => _sessionExpiresAt;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
    required bool rememberSession,
    String? sessionExpiresAt,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userPayload = userPayload;
    _rememberSession = rememberSession;
    _sessionExpiresAt = sessionExpiresAt;
  }
}
