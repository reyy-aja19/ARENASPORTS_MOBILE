import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'api_service.dart';
import 'session_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    await Firebase.initializeApp();
  }
  await PushNotificationService.ensureInitializedForBackground();
  await PushNotificationService.showRemoteNotification(message);
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _lastToken;
  static String? _lastRegisteredToken;
  static int? _lastRegisteredUserId;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _local.initialize(settings);

    await _requestPermission();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(showRemoteNotification);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _lastToken = token;
      await registerTokenIfPossible();
    });

    try {
      _lastToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Gagal mendapatkan FCM token: $e');
    }
  }

  static Future<void> ensureInitializedForBackground() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _local.initialize(settings);
    _initialized = true;
  }

  static Future<void> _requestPermission() async {
    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> showLocalNotification({
    required String title,
    String? body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'arenasports_channel',
      'ARENASPORTS',
      channelDescription: 'Notifikasi booking, event, dan informasi.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> showRemoteNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString() ?? 'ARENASPORTS';
    final body = notification?.body ?? message.data['body']?.toString() ?? message.data['message']?.toString() ?? '';
    final payload = message.data['url']?.toString();
    await showLocalNotification(title: title, body: body, payload: payload);
  }

  static Future<void> registerTokenIfPossible() async {
    final userId = await SessionService.userId();
    final token = _lastToken ?? await FirebaseMessaging.instance.getToken().catchError((_) => null);
    _lastToken = token;
    if (userId == null || token == null || token.isEmpty) return;
    if (_lastRegisteredUserId == userId && _lastRegisteredToken == token) return;

    try {
      await ApiService.instance.registerDeviceToken(
        token: token,
        platform: Platform.operatingSystem,
        deviceName: 'flutter-mobile',
      );
      _lastRegisteredUserId = userId;
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('Gagal register FCM token: $e');
    }
  }

  static Future<void> unregisterCurrentToken() async {
    final token = _lastToken ?? await FirebaseMessaging.instance.getToken().catchError((_) => null);
    if (token == null || token.isEmpty) return;
    await ApiService.instance.unregisterDeviceToken(token);
    if (_lastRegisteredToken == token) {
      _lastRegisteredToken = null;
      _lastRegisteredUserId = null;
    }
  }

  static Future<void> dispose() async {
    _lastRegisteredToken = null;
    _lastRegisteredUserId = null;
  }
}
