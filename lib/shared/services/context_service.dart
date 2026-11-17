import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/context_models.dart';
import '../widgets/update_gate.dart';
import 'auth_service.dart';
import 'context_storage.dart';
import 'context_transport_hooks.dart';
import 'update_policy.dart';

/// Callback signature when an app version gate status is reported via response headers or 426.
typedef UpdatePolicyCallback = void Function({
  required bool isBlocking,
  required String? minVersion,
  required String? clientVersion,
  required String? storeUrl,
  required String? message,
});

/// ContextService manages client-side ContextAPI protocol synchronization,
/// in-memory state hydration, single-flight drain loops, and monotonic slice validation (R1, R3, R5, R10, R14).
class ContextService extends ChangeNotifier implements ContextTransportHooks {
  final ContextStorage _storage;
  final Dio Function() _dioProvider;
  final Random _random = Random();

  int _epoch = 0;
  int _systemVersion = 0;
  int _orgVersion = 0;
  int _userVersion = 0;

  SystemContext? _system;
  OrgContext? _org;
  UserContext? _user;

  bool _isReady = false;
  int? _activeUserId;
  int? _activeOrgId;
  int _lastSyncStartedAtMs = 0;

  // Single-flight drain synchronization (R14)
  Future<void>? _inFlightSync;
  bool _hasPendingRerun = false;

  UpdatePolicyCallback? onUpdatePolicyTriggered;

  ContextService({
    required ContextStorage storage,
    required Dio Function() dioProvider,
  })  : _storage = storage,
        _dioProvider = dioProvider {
    _hydrateFromStorage();
  }

  // --- Getters ---

  int get epoch => _epoch;
  int get systemVersion => _systemVersion;
  int get orgVersion => _orgVersion;
  int get userVersion => _userVersion;

  SystemContext? get system => _system;
  OrgContext? get org => _org;
  UserContext? get user => _user;

  /// Returns effective shift only if not expired (R5).
  /// If expired, returns null and triggers background sync.
  EffectiveShift? get effectiveShift {
    final shift = _user?.effectiveShift;
    if (shift == null) return null;
    if (shift.isExpired) {
      // Trigger background sync to refresh today's shift roster
      triggerSync();
      return null;
    }
    return shift;
  }

  List<AssignedLocation> get assignedLocations => _user?.assignedLocations ?? const [];

  bool get isReady => _isReady;
  int get lastSyncStartedAtMs => _lastSyncStartedAtMs;

  /// Fail-safe captcha status: defaults to true if not loaded or uncertain (R13)
  bool get captchaEnabled => _system?.captchaEnabled ?? true;

  // --- Hydration ---

  void _hydrateFromStorage() {
    final g = _storage.loadGlobal();
    _epoch = g.epoch;
    _systemVersion = g.systemVersion;
    _system = g.system;

    if (_activeOrgId != null && _activeOrgId! > 0) {
      final o = _storage.loadOrg(_activeOrgId!);
      _orgVersion = o.orgVersion;
      _org = o.org;
    }

    if (_activeUserId != null && _activeUserId! > 0) {
      final u = _storage.loadUser(_activeUserId!);
      _userVersion = u.userVersion;
      _user = u.user;
    }

    _isReady = _system != null;
    notifyListeners();
    _evaluateAndApplyUpdatePolicy();
  }

  /// Called on user login / logout / tenant switch (R3).
  Future<void> onIdentityChanged(int? userId, int? orgId) async {
    final userChanged = userId != _activeUserId;
    final orgChanged = orgId != _activeOrgId;

    _activeUserId = userId;
    _activeOrgId = orgId;

    if (userChanged) {
      _user = null;
      _userVersion = 0;
      if (userId != null && userId > 0) {
        final u = _storage.loadUser(userId);
        _userVersion = u.userVersion;
        _user = u.user;
      }
    }

    if (orgChanged) {
      _org = null;
      _orgVersion = 0;
      if (orgId != null && orgId > 0) {
        final o = _storage.loadOrg(orgId);
        _orgVersion = o.orgVersion;
        _org = o.org;
      }
    }

    notifyListeners();

    if (userId != null && userId > 0) {
      await fetchBaseline();
    }
  }

  /// Clears in-memory and persistent state for the active user on logout (R3).
  Future<void> onLogout() async {
    final uid = _activeUserId;
    _activeUserId = null;
    _activeOrgId = null;
    _user = null;
    _userVersion = 0;
    _org = null;
    _orgVersion = 0;

    if (uid != null && uid > 0) {
      await _storage.clearUser(uid);
    }
    notifyListeners();
  }

  // --- ContextTransportHooks Implementation (R10) ---

  @override
  Map<String, String> outgoingHeaders() {
    final vector = ContextVector(
      epoch: _epoch,
      system: _systemVersion,
      org: _orgVersion,
      user: _userVersion,
    );
    return {
      'X-Context-Known': vector.toHeaderValue(),
    };
  }

  @override
  void onResponse(Map<String, List<String>> headers, Object? body) {
    // 1. Process soft/grace update header (R7)
    final updateHeaderList = headers['x-app-update'] ?? headers['X-App-Update'];
    if (updateHeaderList != null && updateHeaderList.isNotEmpty) {
      final raw = updateHeaderList.first;
      _handleAppUpdateHeader(raw);
    }

    // 2. Process version bumps from response header
    final verHeaderList = headers['x-context-version'] ?? headers['X-Context-Version'];
    if (verHeaderList != null && verHeaderList.isNotEmpty) {
      final remoteVector = ContextVector.fromHeader(verHeaderList.first);
      noteRemoteVersions(remoteVector);
    }

    // 3. Process inline delta if returned in body (R14)
    if (body is Map<String, dynamic>) {
      final delta = body['_contextDelta'] as Map<String, dynamic>?;
      if (delta != null) {
        applyDelta(delta);
      }
    }
  }

  void _handleAppUpdateHeader(String header) {
    final parts = header.split(';');
    final policy = parts[0].trim();
    if (policy == 'required') {
      onUpdatePolicyTriggered?.call(
        isBlocking: false, // In grace window
        minVersion: null,
        clientVersion: null,
        storeUrl: null,
        message: 'A mandatory app update is scheduled. Please update to avoid interruption.',
      );
    } else if (policy == 'recommended') {
      onUpdatePolicyTriggered?.call(
        isBlocking: false,
        minVersion: null,
        clientVersion: null,
        storeUrl: null,
        message: 'A recommended update is available for MANO Attendance.',
      );
    }
  }

  // --- Version Verification & Monotonic Application (R14) ---

  /// Compares remote vector against local state and triggers sync if outdated.
  void noteRemoteVersions(ContextVector remote) {
    // Disaster-recovery epoch check
    if (remote.epoch > 0 && remote.epoch != _epoch && _epoch > 0) {
      debugPrint('[ContextService] Disaster-recovery epoch change detected ($_epoch -> ${remote.epoch})');
      fetchBaseline();
      return;
    }

    bool isBehind = false;
    if (remote.epoch > _epoch) isBehind = true;
    if (remote.system > _systemVersion) isBehind = true;
    if (_activeOrgId != null && remote.org > _orgVersion) isBehind = true;
    if (_activeUserId != null && remote.user > _userVersion) isBehind = true;

    if (isBehind) {
      triggerSync();
    }
  }

  /// Monotonically applies a context delta received via HTTP or WebSocket.
  void applyDelta(Map<String, dynamic> delta) {
    bool changed = false;

    // Check epoch
    final deltaEpoch = delta['e'] as int?;
    if (deltaEpoch != null && deltaEpoch != _epoch && _epoch > 0) {
      fetchBaseline();
      return;
    }

    // System slice
    final sVer = delta['s'] as int?;
    final sData = delta['system'] as Map<String, dynamic>?;
    if (sVer != null && sVer > _systemVersion && sData != null) {
      _systemVersion = sVer;
      _system = SystemContext.fromJson(sData);
      _storage.saveGlobal(
        epoch: _epoch,
        systemVersion: _systemVersion,
        system: _system!,
      );
      changed = true;
      _evaluateAndApplyUpdatePolicy();
    }

    // Org slice
    final oVer = delta['o'] as int?;
    final oData = delta['org'] as Map<String, dynamic>?;
    if (oVer != null && oVer > _orgVersion && oData != null && _activeOrgId != null) {
      _orgVersion = oVer;
      _org = OrgContext.fromJson(oData);
      _storage.saveOrg(
        orgId: _activeOrgId!,
        orgVersion: _orgVersion,
        org: _org!,
      );
      changed = true;
    }

    // User slice
    final uVer = delta['u'] as int?;
    final uData = delta['user'] as Map<String, dynamic>?;
    if (uVer != null && uVer > _userVersion && uData != null && _activeUserId != null) {
      _userVersion = uVer;
      _user = UserContext.fromJson(uData);
      _storage.saveUser(
        userId: _activeUserId!,
        userVersion: _userVersion,
        user: _user!,
      );
      changed = true;
    }

    if (changed) {
      _isReady = true;
      notifyListeners();
    }
  }

  // --- Single-Flight Drain Loop (R10, R14) ---

  /// Requests context synchronization. If a sync is already running, latches a rerun.
  Future<void> triggerSync() {
    if (_inFlightSync != null) {
      _hasPendingRerun = true;
      return _inFlightSync!;
    }

    _inFlightSync = _executeDrainLoop().whenComplete(() {
      _inFlightSync = null;
      if (_hasPendingRerun) {
        _hasPendingRerun = false;
        triggerSync();
      }
    });

    return _inFlightSync!;
  }

  Future<void> _executeDrainLoop() async {
    _lastSyncStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    final dio = _dioProvider();

    int attempts = 0;
    const maxAttempts = 6;

    while (attempts < maxAttempts) {
      try {
        final known = outgoingHeaders()['X-Context-Known']!;
        final response = await dio.get(
          '/api/context/sync',
          queryParameters: {'known': known},
          options: Options(
            extra: {'ctx': 'sync'}, // Tagged to prevent interceptor recursion (R10)
          ),
        );

        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          final data = response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>;
          applyDelta(data);
        }
        return; // Success!
      } on DioException catch (e) {
        // Error classification (R10)
        final statusCode = e.response?.statusCode;

        // 1. 426 Force Update: Never retry, report to controller immediately
        if (statusCode == 426) {
          final body = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : {};
          onUpdatePolicyTriggered?.call(
            isBlocking: true,
            minVersion: body['minVersion']?.toString(),
            clientVersion: body['clientVersion']?.toString(),
            storeUrl: body['storeUrl']?.toString(),
            message: body['message']?.toString(),
          );
          return;
        }

        // 2. 401 Unauthorized: Pause drain until user logs in
        if (statusCode == 401) {
          debugPrint('[ContextService] Sync paused due to 401 Unauthorized');
          return;
        }

        // 3. 400 / 404 on delta: Fall back to full baseline
        if (statusCode == 400 || statusCode == 404) {
          await fetchBaseline();
          return;
        }

        // 4. 429 / 5xx / Network error: Exponential backoff with jitter
        attempts++;
        if (attempts >= maxAttempts) {
          debugPrint('[ContextService] Sync drain exceeded max retry attempts');
          return;
        }

        final baseDelayMs = (500 * pow(2, attempts)).toInt().clamp(500, 30000);
        final jitter = (baseDelayMs * 0.2 * (_random.nextDouble() * 2 - 1)).toInt();
        final finalDelayMs = (baseDelayMs + jitter).clamp(200, 30000);

        await Future.delayed(Duration(milliseconds: finalDelayMs));
      } catch (e) {
        debugPrint('[ContextService] Unexpected error in sync drain: $e');
        return;
      }
    }
  }

  /// Fetches complete baseline context for cold-starts or disaster recovery.
  Future<void> fetchBaseline() async {
    final dio = _dioProvider();
    try {
      final response = await dio.get(
        '/api/context/me',
        options: Options(extra: {'ctx': 'sync'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>;
        
        final e = data['e'] as int? ?? 1;
        final sVer = data['s'] as int? ?? 0;
        final oVer = data['o'] as int? ?? 0;
        final uVer = data['u'] as int? ?? 0;

        _epoch = e;
        if (data['system'] != null) {
          _systemVersion = sVer;
          _system = SystemContext.fromJson(data['system'] as Map<String, dynamic>);
          await _storage.saveGlobal(epoch: _epoch, systemVersion: _systemVersion, system: _system!);
          _evaluateAndApplyUpdatePolicy();
        }

        if (data['org'] != null && _activeOrgId != null) {
          _orgVersion = oVer;
          _org = OrgContext.fromJson(data['org'] as Map<String, dynamic>);
          await _storage.saveOrg(orgId: _activeOrgId!, orgVersion: _orgVersion, org: _org!);
        }

        if (data['user'] != null && _activeUserId != null) {
          _userVersion = uVer;
          _user = UserContext.fromJson(data['user'] as Map<String, dynamic>);
          await _storage.saveUser(userId: _activeUserId!, userVersion: _userVersion, user: _user!);
        }

        _isReady = true;
        notifyListeners();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 426) {
        final body = e.response?.data is Map<String, dynamic> ? e.response?.data as Map<String, dynamic> : {};
        onUpdatePolicyTriggered?.call(
          isBlocking: true,
          minVersion: body['minVersion']?.toString(),
          clientVersion: body['clientVersion']?.toString(),
          storeUrl: body['storeUrl']?.toString(),
          message: body['message']?.toString(),
        );
      }
    } catch (_) {}
  }

  /// Synchronously fetches unauthenticated public system context slice (e.g. for login captcha).
  Future<void> syncSystemContext({Duration timeout = const Duration(seconds: 3)}) async {
    final dio = _dioProvider();
    try {
      final response = await dio.get(
        '/api/context/system',
        options: Options(
          extra: {'ctx': 'sync'},
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data['data'] as Map<String, dynamic>? ?? response.data as Map<String, dynamic>;
        final sVer = data['version'] as int? ?? data['s'] as int? ?? 0;
        final slice = data['system'] as Map<String, dynamic>? ??
            data['slice'] as Map<String, dynamic>? ??
            data;

        if (sVer >= _systemVersion) {
          _systemVersion = sVer;
          _system = SystemContext.fromJson(slice);
          await _storage.saveGlobal(
            epoch: _epoch,
            systemVersion: _systemVersion,
            system: _system!,
          );
          _isReady = true;
          notifyListeners();
          _evaluateAndApplyUpdatePolicy();
        }
      }
    } catch (_) {}
  }

  /// Evaluates update policy against current client version and updates the gate.
  void _evaluateAndApplyUpdatePolicy() {
    if (_system == null) return;
    final policy = UpdatePolicy.evaluate(
      system: _system,
      clientVersion: AuthService.cachedAppVersion,
    );
    if (policy.isBlocking) {
      UpdateGateController.instance.require(policy);
    } else if (UpdateGateController.instance.isBlocked) {
      UpdateGateController.instance.clear();
    }
  }
}
