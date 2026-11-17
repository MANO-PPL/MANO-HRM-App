import 'dart:io';
import '../models/context_models.dart';

enum UpdatePolicyState {
  none,
  recommended,
  requiredGrace,
  requiredBlocking,
}

class UpdatePolicyInfo {
  final UpdatePolicyState state;
  final String clientVersion;
  final String minVersion;
  final String recommendedVersion;
  final String storeUrl;
  final DateTime? graceDeadline;
  final String message;

  const UpdatePolicyInfo({
    required this.state,
    required this.clientVersion,
    required this.minVersion,
    required this.recommendedVersion,
    required this.storeUrl,
    this.graceDeadline,
    required this.message,
  });

  bool get isBlocking => state == UpdatePolicyState.requiredBlocking;
}

/// Evaluates the client-side update policy (R7).
class UpdatePolicy {
  static List<int> parseSemver(String? v) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(v?.trim() ?? '');
    if (m != null) {
      return [
        int.tryParse(m.group(1) ?? '0') ?? 0,
        int.tryParse(m.group(2) ?? '0') ?? 0,
        int.tryParse(m.group(3) ?? '0') ?? 0,
      ];
    }
    return [0, 0, 0];
  }

  static bool isVersionOutdated(String clientVer, String minVer) {
    final c = parseSemver(clientVer);
    final m = parseSemver(minVer);
    for (int i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  /// Evaluates the active update policy based on the cached or fresh SystemContext.
  static UpdatePolicyInfo evaluate({
    required SystemContext? system,
    required String clientVersion,
  }) {
    if (system == null) {
      return UpdatePolicyInfo(
        state: UpdatePolicyState.none,
        clientVersion: clientVersion,
        minVersion: '0.0.0',
        recommendedVersion: '0.0.0',
        storeUrl: '',
        message: '',
      );
    }

    final platform = Platform.isIOS ? 'ios' : 'android';
    final minVer = system.minAppVersion[platform] ?? '0.0.0';
    final recVer = system.recommendedVersion[platform] ?? '0.0.0';
    final deadlineMs = system.updateGraceUntil[platform];
    final deadline = deadlineMs != null ? DateTime.fromMillisecondsSinceEpoch(deadlineMs, isUtc: true) : null;
    final storeUrl = system.storeUrls[platform] ?? '';

    // Check if below mandatory minimum version
    if (isVersionOutdated(clientVersion, minVer)) {
      if (deadline != null && DateTime.now().toUtc().isBefore(deadline)) {
        return UpdatePolicyInfo(
          state: UpdatePolicyState.requiredGrace,
          clientVersion: clientVersion,
          minVersion: minVer,
          recommendedVersion: recVer,
          storeUrl: storeUrl,
          graceDeadline: deadline,
          message: 'An update to version $minVer or higher is required soon.',
        );
      }
      return UpdatePolicyInfo(
        state: UpdatePolicyState.requiredBlocking,
        clientVersion: clientVersion,
        minVersion: minVer,
        recommendedVersion: recVer,
        storeUrl: storeUrl,
        graceDeadline: deadline,
        message: 'A new version ($minVer) is required to continue using MANO Attendance.',
      );
    }

    // Check if below recommended version
    if (isVersionOutdated(clientVersion, recVer)) {
      return UpdatePolicyInfo(
        state: UpdatePolicyState.recommended,
        clientVersion: clientVersion,
        minVersion: minVer,
        recommendedVersion: recVer,
        storeUrl: storeUrl,
        graceDeadline: null,
        message: 'A newer version ($recVer) is available with performance and security enhancements.',
      );
    }

    return UpdatePolicyInfo(
      state: UpdatePolicyState.none,
      clientVersion: clientVersion,
      minVersion: minVer,
      recommendedVersion: recVer,
      storeUrl: storeUrl,
      graceDeadline: null,
      message: '',
    );
  }
}
