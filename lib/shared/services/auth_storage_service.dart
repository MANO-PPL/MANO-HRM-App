import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';

/// Centralized secure storage service for authentication credentials and session metadata.
class AuthStorageService {
  static final AuthStorageService _instance = AuthStorageService._internal();
  factory AuthStorageService() => _instance;
  AuthStorageService._internal();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';
  static const String _kSessionId = 'auth_session_id';
  static const String _kRememberMe = 'remember_me';
  static const String _kSavedIdentifier = 'saved_identifier';
  static const String _kLegacySavedEmail = 'saved_email';
  static const String _kCachedUser = 'user';

  // In-memory cache to eliminate redundant platform channel hops on every API request
  String? _cachedAccessToken;

  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required int sessionId,
  }) async {
    _cachedAccessToken = accessToken;
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kSessionId, value: sessionId.toString()),
      _storage.write(key: _kRememberMe, value: 'true'),
    ]);
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    _cachedAccessToken = await _storage.read(key: _kAccessToken);
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  
  Future<int?> getSessionId() async {
    final raw = await _storage.read(key: _kSessionId);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> saveAccessToken(String token) async {
    _cachedAccessToken = token;
    await _storage.write(key: _kAccessToken, value: token);
  }

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _kRefreshToken, value: token);

  Future<void> saveSessionId(int id) =>
      _storage.write(key: _kSessionId, value: id.toString());

  Future<String?> getSavedIdentifier() async {
    return await _storage.read(key: _kSavedIdentifier) ??
        await _storage.read(key: _kLegacySavedEmail);
  }

  /// Mobile sessions always persist. Saves the login identifier for pre-populating login inputs.
  Future<void> saveSavedIdentifier(String identifier) async {
    await _storage.write(key: _kSavedIdentifier, value: identifier);
    await _storage.write(key: _kRememberMe, value: 'true');
  }

  /// Deprecated convenience wrapper: Mobile always persists sessions (remember_me = true).
  Future<void> saveRememberMePreference({
    bool rememberMe = true,
    required String identifier,
  }) async {
    await saveSavedIdentifier(identifier);
  }

  /// Mobile sessions always slide and persist indefinitely (remember_me is hardcoded true).
  Future<bool> getRememberMePreference() async => true;

  Future<String?> getCachedUserJson() => _storage.read(key: _kCachedUser);

  Future<void> saveCachedUserJson(String json) =>
      _storage.write(key: _kCachedUser, value: json);

  /// Clears active credentials while preserving the saved login identifier on mobile.
  Future<void> clearAuthData() async {
    _cachedAccessToken = null;
    final savedIdentifier = await getSavedIdentifier();

    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kSessionId);
    await _storage.delete(key: _kCachedUser);

    await _storage.write(key: _kRememberMe, value: 'true');
    if (savedIdentifier != null && savedIdentifier.isNotEmpty) {
      await _storage.write(key: _kSavedIdentifier, value: savedIdentifier);
    }
  }

  /// One-time migration helper: transfers legacy cookie-jar refresh tokens
  /// into FlutterSecureStorage to prevent existing users from being logged out on upgrade.
  Future<void> migrateLegacyTokensIfNeeded(PersistCookieJar? cookieJar) async {
    try {
      final existingToken = await getRefreshToken();
      if (existingToken != null && existingToken.isNotEmpty) {
        return; // Already has secure token
      }

      if (cookieJar == null) return;

      final uri = Uri.parse(ApiConstants.baseUrl);
      final cookies = await cookieJar.loadForRequest(uri);
      for (final cookie in cookies) {
        if (cookie.name == 'refreshToken' && cookie.value.isNotEmpty) {
          debugPrint('AuthStorageService: Migrating legacy cookie token into secure storage.');
          await saveRefreshToken(cookie.value);
          break;
        }
      }
    } catch (e) {
      debugPrint('AuthStorageService: Migration check error: $e');
    }
  }
}
