import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour les messages
class MessageModel {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final String? text;
  final String? audioUrl;
  final String type; // 'text' ou 'audio'
  final List<String> categories;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MessageModel({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    this.text,
    this.audioUrl,
    required this.type,
    required this.categories,
    required this.createdAt,
    this.updatedAt,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      text: data['text'] as String?,
      audioUrl: data['audioUrl'] as String?,
      type: data['type'] as String? ?? 'text',
      categories: List<String>.from(data['categories'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'audioUrl': audioUrl,
      'type': type,
      'categories': categories,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Service pour gérer les messages
class MessageService {
  MessageService._();
  static final MessageService instance = MessageService._();

  final _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'messages';

  /// Stream des messages pour une catégorie spécifique
  Stream<List<MessageModel>> getMessagesByCategoryStream(String category) {
    return _firestore
        .collection(_collectionName)
        .where('categories', arrayContains: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
        })
        .handleError((error) {
          print('Erreur lors de la récupération des messages: $error');
          return <MessageModel>[];
        });
  }

  /// Récupère les messages pour une catégorie (une fois)
  Future<List<MessageModel>> getMessagesByCategory(
    String category, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('categories', arrayContains: category)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des messages: $e');
      return [];
    }
  }

  /// Envoie un message texte
  Future<String?> sendTextMessage({
    required String senderId,
    required String text,
    required List<String> categories,
    String? senderName,
    String? senderPhotoUrl,
  }) async {
    try {
      if (text.trim().isEmpty) {
        throw Exception('Le message ne peut pas être vide');
      }

      final docRef = await _firestore.collection(_collectionName).add({
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'text': text.trim(),
        'type': 'text',
        'categories': categories,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Erreur lors de l\'envoi du message texte: $e');
      rethrow;
    }
  }

  /// Envoie un message audio
  Future<String?> sendAudioMessage({
    required String senderId,
    required String audioUrl,
    required List<String> categories,
    String? senderName,
    String? senderPhotoUrl,
  }) async {
    try {
      if (audioUrl.isEmpty) {
        throw Exception('L\'URL audio ne peut pas être vide');
      }

      final docRef = await _firestore.collection(_collectionName).add({
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'audioUrl': audioUrl,
        'type': 'audio',
        'categories': categories,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Erreur lors de l\'envoi du message audio: $e');
      rethrow;
    }
  }

  /// Supprime un message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection(_collectionName).doc(messageId).delete();
    } catch (e) {
      print('Erreur lors de la suppression du message: $e');
      rethrow;
    }
  }

  /// Met à jour un message texte
  Future<void> updateTextMessage(
    String messageId,
    String newText,
  ) async {
    try {
      if (newText.trim().isEmpty) {
        throw Exception('Le message ne peut pas être vide');
      }

      await _firestore.collection(_collectionName).doc(messageId).update({
        'text': newText.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de la mise à jour du message: $e');
      rethrow;
    }
  }

  /// Récupère un message par ID
  Future<MessageModel?> getMessageById(String messageId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(messageId).get();
      if (!doc.exists) return null;
      return MessageModel.fromFirestore(doc);
    } catch (e) {
      print('Erreur lors de la récupération du message: $e');
      return null;
    }
  }

  /// Cherche des messages
  Future<List<MessageModel>> searchMessages(
    String query, {
    String? category,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      var q = _firestore.collection(_collectionName).where('text',
          isGreaterThanOrEqualTo: query.trim(),
          isLessThan: '${query.trim()}z');

      if (category != null) {
        q = q.where('categories', arrayContains: category);
      }

      final snapshot =
          await q.orderBy('createdAt', descending: true).limit(20).get();

      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Erreur lors de la recherche: $e');
      return [];
    }
  }
}
