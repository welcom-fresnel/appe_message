import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service pour écouter les nouveaux messages et afficher les notifications
class MessageListenerService {
  MessageListenerService._();
  static final MessageListenerService instance = MessageListenerService._();

  late String _userCategory;
  DateTime _lastNotificationTime = DateTime.now();

  Future<void> startListening() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Récupérer la catégorie de l'utilisateur
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      _userCategory = userDoc['category'] ?? '';
      if (_userCategory.isEmpty) return;

      print('👂 Écoute des messages pour la catégorie: $_userCategory');

      try {
        // Subscribe to per-user topic to receive conversation notifications
        await FirebaseMessaging.instance.subscribeToTopic('user_${currentUser.uid}');
      } catch (e) {
        print('⚠️ Erreur subscription topic: $e');
      }

      // Écouter les nouveaux messages
      FirebaseFirestore.instance
          .collection('messages')
          .where('categories', arrayContains: _userCategory)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final message = snapshot.docs.first;
          final createdAt = (message['createdAt'] as Timestamp?)?.toDate();

          // Vérifier que c'est un message récent (éviter les doublons)
          if (createdAt != null &&
              DateTime.now().difference(createdAt).inSeconds < 60) {
            // Éviter les notifications en spam (1 par 5 secondes)
            if (DateTime.now().difference(_lastNotificationTime).inSeconds >= 5) {
              _showMessageNotification(message);
              _lastNotificationTime = DateTime.now();
            }
          }
        }
      });
    } catch (e) {
      print('❌ Erreur lors de l\'écoute des messages: $e');
    }
  }

  void _showMessageNotification(DocumentSnapshot message) {
    final senderName = message['senderName'] ?? 'Admin';
    final text = message['text'] ?? '';
    final type = message['type'] ?? 'text';

    String body = text;
    if (type == 'audio') {
      body = '🎤 Message vocal';
    }

    if (body.length > 100) {
      body = '${body.substring(0, 100)}...';
    }

    NotificationService.instance.show(
      title: '📢 Nouvelle annonce de $senderName',
      body: body,
      payload: message.id,
    );

    print('🔔 Notification affichée: $senderName');
  }

  void stopListening() {
    print('👋 Arrêt de l\'écoute des messages');
  }
}
