import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class InAppUpdateService {
  /// Checks for application updates from the Google Play Store on Android devices.
  /// Handles both immediate (mandatory) and flexible (background) updates gracefully.
  static Future<void> checkForUpdates(BuildContext context) async {
    // Google Play In-App Updates are only supported on Android.
    if (!Platform.isAndroid) {
      debugPrint("InAppUpdateService: Skipping check (Non-Android platform)");
      return;
    }

    try {
      debugPrint("InAppUpdateService: Checking for updates...");
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint("InAppUpdateService: Update available!");

        if (updateInfo.immediateUpdateAllowed) {
          debugPrint("InAppUpdateService: Starting immediate update flow...");
          // Triggers immediate update flow (blocking full-screen UI)
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          debugPrint("InAppUpdateService: Starting flexible background update flow...");
          // Triggers flexible update flow (background download)
          await InAppUpdate.startFlexibleUpdate();

          // After downloading, ask the user to restart the app to apply changes
          if (context.mounted) {
            context.showToast(
              "Update downloaded. Tap Restart to install.",
              isSuccess: true,
              actionLabel: "RESTART",
              onActionPressed: () async {
                try {
                  await InAppUpdate.completeFlexibleUpdate();
                } catch (e) {
                  debugPrint("InAppUpdateService: Error completing flexible update: $e");
                  if (context.mounted) {
                    context.showToast(
                      "Failed to install update. Please try again.",
                      isError: true,
                    );
                  }
                }
              },
            );
          }
        }
      } else {
        debugPrint("InAppUpdateService: App is up-to-date");
      }
    } catch (e) {
      // Catching any Google Play Core exceptions (e.g. signature mismatch, debug build, API not available)
      // to prevent crashes and log gracefully during development.
      debugPrint("InAppUpdateService: In-App Update API failed gracefully: $e");
    }
  }
}
