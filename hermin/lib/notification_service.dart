import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  late AndroidNotificationChannel _androidChannel;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(initSettings);

    _androidChannel = const AndroidNotificationChannel(
      'hermin_default',
      'Hermin Notifications',
      importance: Importance.max,
      playSound: true,
    );

    await _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_androidChannel);
  }

  Future<void> show({required int id, required String title, required String body}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
    await _fln.show(id, title, body, details);
  }
}
