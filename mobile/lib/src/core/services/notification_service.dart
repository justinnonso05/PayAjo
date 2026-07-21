import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background FCM message: ${message.messageId}");
}

const _kAndroidChannel = AndroidNotificationChannel(
  'payajo_default',
  'General notifications',
  description: 'Group activity, reminders, and account updates.',
  importance: Importance.high,
);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;

  String? get currentToken => _currentToken;

  /// Initializes FCM listeners, requests permissions, and fetches the token.
  Future<void> initialize() async {
    await _initLocalNotifications();

    // Request permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('User notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Get current FCM token
      try {
        _currentToken = await _messaging.getToken();
        debugPrint('FCM Token: $_currentToken');
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }

      // Listen to token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        syncTokenWithBackend(newToken);
      });

      // FCM only auto-shows a system notification when the app is
      // backgrounded/closed — in the foreground it just delivers the data
      // silently, so we have to display it ourselves to match that behavior.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM notification: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // Handle notification open/tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM notification opened app: ${message.data}');
      });
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_kAndroidChannel);
    // flutter_local_notifications gates POST_NOTIFICATIONS on Android 13+
    // through its own permission call — separate from FirebaseMessaging's,
    // even though both map to the same OS permission. Without this, `.show()`
    // can silently no-op on some Android versions even after FCM's own
    // requestPermission() reported "authorized".
    final granted = await androidPlugin?.requestNotificationsPermission();
    debugPrint('flutter_local_notifications permission granted: $granted');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      debugPrint('Skipped local notification: message had no `notification` payload.');
      return;
    }
    try {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kAndroidChannel.id,
            _kAndroidChannel.name,
            channelDescription: _kAndroidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      debugPrint('Local notification shown for foreground message.');
    } catch (e) {
      debugPrint('Failed to show local notification: $e');
    }
  }

  /// Sends the current FCM token to the backend API.
  Future<void> syncTokenWithBackend(String? token) async {
    final tokenToSend = token ?? _currentToken;
    if (tokenToSend == null || tokenToSend.isEmpty) return;

    try {
      final authToken = await SecureStorageService().readAccessToken();
      if (authToken == null || authToken.isEmpty) return;

      final client = ApiClient();
      await client.post(
        ApiConstants.fcmToken,
        body: {'fcm_token': tokenToSend},
        headers: {'Authorization': 'Bearer $authToken'},
      );
      debugPrint('FCM Token successfully synced with backend.');
    } catch (e) {
      debugPrint('Failed to sync FCM Token with backend: $e');
    }
  }
}
