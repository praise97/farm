import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../offline/local_store.dart';

/// Local phone notifications for farm alerts (works offline; FCM optional later).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'roots_alerts',
              'Roots Alerts',
              description: 'Vaccinations, stock, weather and farm reminders',
              importance: Importance.high,
            ),
          );
      await Permission.notification.request();
    }
    _ready = true;
  }

  Future<void> showAlert({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!LocalStore.instance.notificationsEnabled) return;
    if (!_ready) await init();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'roots_alerts',
        'Roots Alerts',
        channelDescription: 'Vaccinations, stock, weather and farm reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }
}
