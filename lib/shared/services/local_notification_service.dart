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

  // ── Deduplication: prevent same title from firing twice in 30 seconds ──────
  // Key: notification title (lowercased), Value: timestamp of last show
  static final Map<String, DateTime> _recentTitles = {};
  static const Duration _dedupWindow = Duration(seconds: 30);

  /// Returns true if this notification title was already shown within [_dedupWindow].
  static bool _isDuplicateTitle(String title) {
    final key = title.toLowerCase().trim();
    final last = _recentTitles[key];
    if (last != null && DateTime.now().difference(last) < _dedupWindow) {
      debugPrint('LocalNotificationService: Suppressed duplicate notification "$title"');
      return true;
    }
    _recentTitles[key] = DateTime.now();
    // Prune stale entries to prevent unbounded growth
    _recentTitles.removeWhere((_, ts) => DateTime.now().difference(ts) > _dedupWindow * 2);
    return false;
  }

  /// Derives a stable integer ID from a string (e.g. a notification title).
  /// The result is always in [1, 99999] so it stays within Android's int range
  /// and is stable across calls with the same input — meaning the next show()
  /// with the same title replaces the previous one on the notification tray
  /// instead of stacking up.
  static int _stableId(String title) {
    var hash = 0;
    for (final c in title.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return (hash % 99999) + 1; // keep in [1, 99999]
  }

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
  /// • If [id] is 0 (default), a **stable content-derived ID** is computed from
  ///   [title] so repeat calls with the same title REPLACE the existing
  ///   notification instead of stacking new ones.
  /// • A 30-second dedup window suppresses identical titles fired in rapid succession.
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
    // Deduplicate: suppress if same title was shown within the dedup window
    if (id == 0 && _isDuplicateTitle(title)) return;

    // Ensure channel exists if called from background isolate
    await _createAndroidChannel();

    // Use caller-supplied ID or derive a stable one from the title
    final notifId = id != 0 ? id : _stableId(title);

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

    try {
      await _plugin.show(
        notifId,
        title,
        body,
        details,
        payload: data != null ? jsonEncode(data) : null,
      );
      debugPrint('LocalNotificationService: Showed notification id=$notifId "$title"');
    } catch (e) {
      debugPrint('LocalNotificationService: error showing notification: $e');
    }
  }

  /// Schedules a local notification to show at a future time.
  ///
  /// Always cancels any existing notification with [id] before scheduling the
  /// new one, so only one instance of each shift-reminder ever exists.
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
