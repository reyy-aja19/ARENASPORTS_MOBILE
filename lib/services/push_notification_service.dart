import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handler untuk pesan FCM yang diterima saat app di background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.showRemoteNotification(message);
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static dynamic _inboxSub;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _local.initialize(settings);

    await _requestPermission();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) {
      showRemoteNotification(message);
    });

    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token: $token');
    } catch (e) {
      debugPrint('Gagal mendapatkan FCM token: $e');
    }
  }

  static Future<void> _requestPermission() async {
    final androidImpl = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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
      channelDescription: 'Notifikasi booking, pertemanan, dan reward.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
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
    final title = notification?.title ?? 'ARENASPORTS';
    final body = notification?.body ?? '';
    await showLocalNotification(title: title, body: body);
  }

  /// Mendengarkan inbox Firestore agar notifikasi (termasuk saat app di
  /// background) muncul sebagai notifikasi sistem.
  static void listenToInbox(int userId) {
    _inboxSub?.cancel();
    try {
      _inboxSub = FirebaseFirestore.instance
          .collection('users')
          .doc('$userId')
          .collection('inbox')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snap) {
            for (final change in snap.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                showLocalNotification(
                  title: (data?['title'] ?? 'ARENASPORTS').toString(),
                  body: data?['body']?.toString(),
                );
                change.doc.reference.update({'read': true});
              }
            }
          }, onError: (e) => debugPrint('inbox listener error: $e'));
    } catch (e) {
      debugPrint('Gagal listen inbox: $e');
    }
  }

  static Future<void> sendToInbox(
    int recipientId,
    String title,
    String body,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('$recipientId')
          .collection('inbox')
          .add({
            'title': title,
            'body': body,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Gagal kirim inbox: $e');
    }
  }

  static Future<void> saveTokenForUser(int userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc('$userId').set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Gagal simpan FCM token: $e');
    }
  }

  /// Mengirim notifikasi ke user lain. Jika FCM_SERVER_KEY diset (via
  /// --dart-define), push dikirim langsung ke token penerima (muncul walau app
  /// tertutup). Jika tidak, fallback ke inbox Firestore (muncul saat app
  /// dibuka/di background).
  static Future<void> sendPushToUser(
    int recipientId,
    String title,
    String body,
  ) async {
    const serverKey = String.fromEnvironment('FCM_SERVER_KEY');
    if (serverKey.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('$recipientId')
            .get();
        final token = doc.data()?['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          final response = await http.post(
            Uri.parse('https://fcm.googleapis.com/fcm/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'key=$serverKey',
            },
            body: jsonEncode({
              'to': token,
              'notification': {'title': title, 'body': body},
              'priority': 'high',
            }),
          );
          if (response.statusCode == 200) return;
        }
      } catch (e) {
        debugPrint('FCM direct send gagal: $e');
      }
    }
    await sendToInbox(recipientId, title, body);
  }

  static void dispose() {
    _inboxSub?.cancel();
    _inboxSub = null;
  }
}
