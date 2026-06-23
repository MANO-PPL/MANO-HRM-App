import 'dart:ui' show Color;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] to provide a single place for:
///
///  • Creating the Android notification channel on app boot.
///  • Showing a local notification from any isolate (foreground / background / killed).
///  • Routing the user to the Notifications page when they tap a notification.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// The channel used for all app push notifications.
  /// Must match `com.google.firebase.messaging.default_notification_channel_id`
  /// in AndroidManifest.xml and the backend FCM payload's `channelId`.
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'MANO Notifications';
  static const String _channelDescription =
      'Attendance, leave, and work-related notifications from MANO';

  /// Called once during [main] before [runApp].
  static Future<void> initialize({
    /// Optional callback fired when the user taps a notification
    /// while the app is in the foreground or resumed from background.
    void Function(NotificationResponse)? onNotificationTap,
  }) async {
    // Initialize timezone database
    tz.initializeTimeZones();

    // ── Android settings ──────────────────────────────────────────────────
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');

    // ── iOS / macOS settings ──────────────────────────────────────────────
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // handled by firebase_messaging
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
      // Called when app was completely killed and user tapped a local notification
      onDidReceiveBackgroundNotificationResponse: _backgroundTapHandler,
    );

    // Create the high-importance Android channel (no-op if already exists)
    await _createAndroidChannel();
  }

  /// Creates the Android notification channel.
  /// Safe to call multiple times — Android is idempotent for identical channels.
  static Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,      // shows as heads-up (banner)
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Shows a notification immediately on the current device.
  ///
  /// Safe to call from:
  ///  • The main isolate (foreground `onMessage` handler)
  ///  • The background isolate (`_firebaseMessagingBackgroundHandler`)
  static Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int id = 0,
  }) async {
    // Ensure channel exists if called from background isolate
    await _createAndroidChannel();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Use the monochrome vector icon declared in AndroidManifest.xml
      icon: '@drawable/ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('app_icon'),
      color: const Color(0xFF5B60F6), // brand purple
      showWhen: true,
      // Allows the notification to show even in Do Not Disturb
      category: AndroidNotificationCategory.message,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // Use a stable ID based on timestamp so multiple notifications don't overwrite each other
    final notifId = id != 0 ? id : DateTime.now().millisecondsSinceEpoch % 100000;

    try {
      await _plugin.show(
        notifId,
        title,
        body,
        details,
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      debugPrint('LocalNotificationService: error showing notification: $e');
    }
  }

  /// Schedules a local notification to show at a future time.
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    Map<String, dynamic>? data,
  }) async {
    await _createAndroidChannel();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('app_icon'),
      color: const Color(0xFF5B60F6),
      showWhen: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final localTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    try {
      // Cancel any existing scheduled notification with this ID first
      await _plugin.cancel(id);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        localTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: data != null ? jsonEncode(data) : null,
      );
      debugPrint('LocalNotificationService: Scheduled notification $id at $localTime');
    } catch (e) {
      debugPrint('LocalNotificationService: error scheduling notification: $e');
    }
  }

  /// Cancels a scheduled local notification.
  static Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
      debugPrint('LocalNotificationService: Cancelled notification $id');
    } catch (e) {
      debugPrint('LocalNotificationService: error cancelling notification: $e');
    }
  }

  /// Returns the notification that launched the app from a terminated state
  /// (i.e. the user tapped a local notification while the app was killed).
  ///
  /// Should be checked once in [main] after [initialize].
  static Future<NotificationAppLaunchDetails?> getLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();
}

/// Top-level function required by flutter_local_notifications for background tap handling.
/// Must be a top-level (non-anonymous) function annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void _backgroundTapHandler(NotificationResponse response) {
  // The app is already being launched by the tap; no extra action needed here.
  // Navigation happens in NotificationService via onMessageOpenedApp / getInitialMessage.
  debugPrint('LocalNotificationService: background tap — payload: ${response.payload}');
}
