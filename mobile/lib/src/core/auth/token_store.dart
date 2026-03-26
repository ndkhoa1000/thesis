import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<String?> readUserPayload();

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
  });

  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userPayloadKey = 'user_payload';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userPayloadKey);
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
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userPayloadKey, value: userPayload);
  }
}

class MemoryTokenStore implements TokenStore {
  String? _accessToken;
  String? _refreshToken;
  String? _userPayload;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _userPayload = null;
  }

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<String?> readUserPayload() async => _userPayload;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userPayload,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userPayload = userPayload;
  }
}
