import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hermin/services/cloudinary_service.dart';

class ConversationService {
  ConversationService._();
  static final ConversationService instance = ConversationService._();

  final _fs = FirebaseFirestore.instance;

  /// Crée ou récupère une conversation entre les participants (order-insensitive)
  Future<DocumentReference<Map<String, dynamic>>> getOrCreateConversation(List<String> participants, {String? title}) async {
    // Try to find existing conversation with same participants
    final snap = await _fs
        .collection('conversations')
        .where('participants', arrayContainsAny: participants)
        .limit(20)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final p = List<String>.from(data['participants'] ?? []);
      if (_listEqualsIgnoreOrder(p, participants)) {
        return doc.reference;
      }
    }

    // Create new
    final ref = await _fs.collection('conversations').add({
      'participants': participants,
      'title': title ?? '',
      'lastMessage': '',
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ref;
  }

  bool _listEqualsIgnoreOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final aa = List<String>.from(a)..sort();
    final bb = List<String>.from(b)..sort();
    for (var i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
  }

  /// Send a text or media message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    String? text,
    List<String>? mediaUrls,
    String type = 'text',
  }) async {
    final msg = <String, dynamic>{
      'senderId': senderId,
      'text': text ?? '',
      'mediaUrls': mediaUrls ?? [],
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final msgsRef = _fs.collection('conversations').doc(conversationId).collection('messages');
  await msgsRef.add(msg);

    // update conversation
    await _fs.collection('conversations').doc(conversationId).update({
      'lastMessage': (text != null && text.isNotEmpty) ? text : (mediaUrls != null && mediaUrls.isNotEmpty ? '📷 Image' : ''),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return;
  }

  /// Upload image(s) and send as message
  Future<void> sendImageMessage({
    required String conversationId,
    required String senderId,
    required List<File> images,
  }) async {
    final urls = <String>[];
    for (final f in images) {
      final resp = await CloudinaryService.instance.uploadImage(f);
      if (resp != null) urls.add(resp.secureUrl);
    }

    await sendMessage(conversationId: conversationId, senderId: senderId, mediaUrls: urls, type: 'image');
  }

  /// Stream list of conversations for current user
  Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream(String userId) {
    return _fs
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  /// Stream messages for a conversation
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _fs
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}
