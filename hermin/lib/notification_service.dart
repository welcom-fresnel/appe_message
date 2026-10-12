import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service pour afficher les notifications locales
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  late AndroidNotificationChannel _androidChannel;
  final _random = Random();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _fln.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    _androidChannel = const AndroidNotificationChannel(
      'hermin_default',
      'Hermin Notifications',
      description: 'Channel pour les notifications Hermin',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  /// Affiche une notification
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        sound: const RawResourceAndroidNotificationSound('bell'),
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
      ),
    );

    await _fln.show(
      id: _generateUniqueId(),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );

    debugPrint('Notification affichee: $title');
  }

  /// Genere un ID unique pour eviter les collisions
  int _generateUniqueId() {
    return _random.nextInt(2147483647);
  }

  /// Gere le tap sur une notification
  void _handleNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapee: ${response.payload}');
    // Tu peux ajouter la navigation ici
  }
}
