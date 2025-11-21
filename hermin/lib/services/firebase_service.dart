import 'package:firebase_messaging/firebase_messaging.dart';

/// Service centralisé pour gérer Firebase Messaging
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  late FirebaseMessaging _messaging;

  Future<void> initialize() async {
    _messaging = FirebaseMessaging.instance;

    // Demander les permissions de notifications
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Configuration du handler pour les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Récupère le token FCM (utile pour envoyer des notifications ciblées)
  Future<String?> getFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('Erreur lors de la récupération du token FCM: $e');
      return null;
    }
  }

  /// Écoute les messages entrants
  Stream<RemoteMessage> get onMessageStream => FirebaseMessaging.onMessage;

  /// Écoute quand l'app est lancée depuis une notification
  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }
}

/// Handler pour les messages reçus quand l'app est fermée
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Message reçu en arrière-plan: ${message.messageId}');
}
