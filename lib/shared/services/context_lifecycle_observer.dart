import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'context_service.dart';
import 'socket_service.dart';

/// Monitors application lifecycle transitions to manage background context sync,
/// isolate communication, and debounced socket preservation (R6, R14, R15).
class ContextLifecycleObserver with WidgetsBindingObserver {
  final ContextService _contextService;
  final SocketService _socketService;
  Timer? _socketDisconnectTimer;
  int _lastResumeCheckMs = 0;

  static const int throttleResumeSyncMs = 30_000; // 30 seconds
  static const int socketPausedDebounceSeconds = 60; // 60 seconds (R15)

  ContextLifecycleObserver({
    required ContextService contextService,
    required SocketService socketService,
  })  : _contextService = contextService,
        _socketService = socketService;

  void register() {
    WidgetsBinding.instance.addObserver(this);
  }

  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
    _socketDisconnectTimer?.cancel();
    _socketDisconnectTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleResumed();
        break;
      case AppLifecycleState.paused:
        _handlePaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _handleResumed() async {
    // 1. Cancel pending socket disconnect timer (R15)
    if (_socketDisconnectTimer != null) {
      _socketDisconnectTimer?.cancel();
      _socketDisconnectTimer = null;
    }

    // 2. Reconnect realtime socket channel if needed
    _socketService.connect();

    // 3. Reload SharedPreferences across isolate boundaries (R6)
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final dirtyAt = prefs.getInt('context_dirty_at') ?? 0;
    final lastSyncStarted = _contextService.lastSyncStartedAtMs;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Trigger sync if background FCM isolate flagged a dirty bump, or if 30s elapsed
    if (dirtyAt > lastSyncStarted || (now - _lastResumeCheckMs > throttleResumeSyncMs)) {
      _lastResumeCheckMs = now;
      _contextService.triggerSync();
    }
  }

  void _handlePaused() {
    // R15: Do NOT disconnect socket immediately!
    // Start a 60-second timer to avoid socket flapping when camera, biometric dialog,
    // or permission prompt takes focus during attendance punch flows.
    _socketDisconnectTimer?.cancel();
    _socketDisconnectTimer = Timer(const Duration(seconds: socketPausedDebounceSeconds), () {
      debugPrint('[ContextLifecycleObserver] Paused timeout reached (60s). Disconnecting socket.');
      _socketService.disconnect();
    });
  }
}
