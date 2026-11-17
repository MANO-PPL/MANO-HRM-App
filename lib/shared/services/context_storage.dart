import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/context_models.dart';

/// Namespaced persistent storage for the ContextAPI subsystem (R3).
/// Separates global pre-login state, per-org operational state, and per-user employee state
/// to prevent cross-account cache leakage on shared mobile devices.
class ContextStorage {
  static const int currentSchemaVersion = 1;
  static const String keySchemaVersion = 'context_schema_version';
  static const String keyGlobal = 'context_global';
  static const String keyDirtyAt = 'context_dirty_at';

  static String keyOrg(int orgId) => 'context_org_$orgId';
  static String keyUser(int userId) => 'context_user_$userId';

  final SharedPreferences _prefs;

  ContextStorage(this._prefs);

  /// Initializes schema and handles version migrations if necessary.
  Future<void> init() async {
    final version = _prefs.getInt(keySchemaVersion) ?? 0;
    if (version < currentSchemaVersion) {
      await _prefs.setInt(keySchemaVersion, currentSchemaVersion);
    }
  }

  // --- Global Scope ('e' and 's') ---

  ({int epoch, int systemVersion, SystemContext? system}) loadGlobal() {
    final raw = _prefs.getString(keyGlobal);
    if (raw == null) {
      return (epoch: 0, systemVersion: 0, system: null);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final epoch = map['e'] as int? ?? 0;
      final sVer = map['s'] as int? ?? 0;
      final sysJson = map['system'] as Map<String, dynamic>?;
      final sys = sysJson != null ? SystemContext.fromJson(sysJson) : null;
      return (epoch: epoch, systemVersion: sVer, system: sys);
    } catch (_) {
      return (epoch: 0, systemVersion: 0, system: null);
    }
  }

  Future<void> saveGlobal({
    required int epoch,
    required int systemVersion,
    required SystemContext system,
  }) async {
    final data = {
      'e': epoch,
      's': systemVersion,
      'system': system.toJson(),
    };
    await _prefs.setString(keyGlobal, jsonEncode(data));
  }

  // --- Organization Scope ('o') ---

  ({int orgVersion, OrgContext? org}) loadOrg(int orgId) {
    if (orgId <= 0) return (orgVersion: 0, org: null);
    final raw = _prefs.getString(keyOrg(orgId));
    if (raw == null) return (orgVersion: 0, org: null);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final oVer = map['o'] as int? ?? 0;
      final sliceJson = map['slice'] as Map<String, dynamic>?;
      final org = sliceJson != null ? OrgContext.fromJson(sliceJson) : null;
      return (orgVersion: oVer, org: org);
    } catch (_) {
      return (orgVersion: 0, org: null);
    }
  }

  Future<void> saveOrg({
    required int orgId,
    required int orgVersion,
    required OrgContext org,
  }) async {
    if (orgId <= 0) return;
    final data = {
      'o': orgVersion,
      'slice': org.toJson(),
    };
    await _prefs.setString(keyOrg(orgId), jsonEncode(data));
  }

  // --- User Scope ('u') ---

  ({int userVersion, UserContext? user}) loadUser(int userId) {
    if (userId <= 0) return (userVersion: 0, user: null);
    final raw = _prefs.getString(keyUser(userId));
    if (raw == null) return (userVersion: 0, user: null);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final uVer = map['u'] as int? ?? 0;
      final sliceJson = map['slice'] as Map<String, dynamic>?;
      final user = sliceJson != null ? UserContext.fromJson(sliceJson) : null;
      return (userVersion: uVer, user: user);
    } catch (_) {
      return (userVersion: 0, user: null);
    }
  }

  Future<void> saveUser({
    required int userId,
    required int userVersion,
    required UserContext user,
  }) async {
    if (userId <= 0) return;
    final data = {
      'u': userVersion,
      'slice': user.toJson(),
      'fetchedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString(keyUser(userId), jsonEncode(data));
  }

  /// Clears user-specific cached context on logout to prevent data leakage (R3).
  Future<void> clearUser(int userId) async {
    if (userId > 0) {
      await _prefs.remove(keyUser(userId));
    }
  }

  // --- Multi-Isolate Dirty Timestamp (R6) ---

  int getDirtyTimestamp() {
    return _prefs.getInt(keyDirtyAt) ?? 0;
  }

  Future<void> recordDirtyTimestamp(int timestampMs) async {
    await _prefs.setInt(keyDirtyAt, timestampMs);
  }

  // --- Vector Composition ---

  /// Composes the X-Context-Known vector strictly for the active user and org (R3).
  ContextVector composeVector({required int? orgId, required int? userId}) {
    final g = loadGlobal();
    final o = orgId != null && orgId > 0 ? loadOrg(orgId) : (orgVersion: 0, org: null);
    final u = userId != null && userId > 0 ? loadUser(userId) : (userVersion: 0, user: null);

    return ContextVector(
      epoch: g.epoch,
      system: g.systemVersion,
      org: o.orgVersion,
      user: u.userVersion,
    );
  }
}
