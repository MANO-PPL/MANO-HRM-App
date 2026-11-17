import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../widgets/update_gate.dart';
import 'update_policy.dart';

/// Service managing Google Play In-App Updates and flexible restart flows (R7, R15).
class InAppUpdateService {
  static bool _flexibleDownloadReady = false;

  /// Dispatches the appropriate update flow based on the client UpdatePolicy.
  static Future<void> handlePolicyUpdate(
    BuildContext context,
    UpdatePolicyInfo policy,
  ) async {
    if (!Platform.isAndroid) return;

    if (policy.state == UpdatePolicyState.none) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (policy.isBlocking && updateInfo.immediateUpdateAllowed) {
          // Play Store full-screen immediate update flow
          await InAppUpdate.performImmediateUpdate();
          return;
        }

        if (updateInfo.flexibleUpdateAllowed) {
          // Silent background download
          await InAppUpdate.startFlexibleUpdate();
          _flexibleDownloadReady = true;

          if (context.mounted) {
            showFlexibleUpdateSnackBar(context);
          }
          return;
        }
      }
    } catch (e) {
      // Swallowed for sideloaded/debug/MDM APKs (A4)
      debugPrint('[InAppUpdateService] Play In-App Update API threw: $e');
    }

    // Fall back to blocking dialog if update is required and Play Store in-app update could not run
    if (policy.isBlocking) {
      UpdateGateController.instance.require(policy);
    }
  }

  /// Displays an indefinite persistent SnackBar prompting the user to restart and complete the update (R15).
  static void showFlexibleUpdateSnackBar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 365), // Persistent until interacted with
        content: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Update downloaded! Restart to apply changes.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: const Color(0xFF38BDF8),
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('[InAppUpdateService] Complete flexible update error: $e');
            }
          },
        ),
      ),
    );
  }

  /// Called on app resumed to check if a downloaded update is awaiting restart.
  static void checkResumedInstall(BuildContext context) {
    if (!Platform.isAndroid) return;
    if (_flexibleDownloadReady && context.mounted) {
      showFlexibleUpdateSnackBar(context);
    }
  }

  /// Entry point checking update status at boot.
  static Future<void> checkForUpdates(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          _flexibleDownloadReady = true;
          if (context.mounted) {
            showFlexibleUpdateSnackBar(context);
          }
        }
      }
    } catch (e) {
      debugPrint('[InAppUpdateService] checkForUpdates threw: $e');
    }
  }
}
