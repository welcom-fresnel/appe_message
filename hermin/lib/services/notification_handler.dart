import 'package:firebase_messaging/firebase_messaging.dart';
import '../notification_service.dart';
import 'firebase_service.dart';

/// Service pour gérer l'écoute et l'affichage des notifications à l'app startup
class NotificationHandler {
  /// Callback pour notifier l'UI d'une nouvelle notification
  void Function()? onNotificationReceived;
  NotificationHandler._();
  static final NotificationHandler instance = NotificationHandler._();

  Future<void> initialize() async {
    // Initialiser le service local de notifications
    await NotificationService.instance.init();

    // Écouter les messages entrants (app au premier plan)
    _setupForegroundNotifications();

    // Gérer les taps sur notifications
    _setupNotificationTapHandling();
  }

  /// Configure l'écoute des notifications au premier plan
  void _setupForegroundNotifications() {
    FirebaseService.instance.onMessageStream.listen((RemoteMessage message) {
      _handleRemoteMessage(message);
    });
  }

  /// Gère l'affichage des notifications
  void _handleRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    // Logs
    print('📨 Message reçu: ${message.messageId}');
    print('Titre: ${notification?.title}');
    print('Corps: ${notification?.body}');
    print('Data: $data');

    // Afficher la notification locale si elle contient titre et corps
    if (notification != null) {
      NotificationService.instance.show(
        title: notification.title ?? 'Nouvelle notification',
        body: notification.body ?? '',
        payload: message.messageId ?? '',
      );
      // Notifie l'UI
      if (onNotificationReceived != null) {
        onNotificationReceived!();
      }
    }
  }

  /// Gère quand on clique sur une notification (app au premier plan ou tuée)
  void _setupNotificationTapHandling() {
    // Quand l'app est lancée depuis une notification (tuée)
    FirebaseService.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🔔 App lancée depuis notification');
        _handleRemoteMessage(message);
      }
    });

    // Quand on clique sur une notification (app au premier plan)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📲 Notification tapée');
      _handleRemoteMessage(message);
    });
  }
}
