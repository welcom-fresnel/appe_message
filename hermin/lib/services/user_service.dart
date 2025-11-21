import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modèle utilisateur
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? category;
  final String? photoUrl;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.category,
    this.photoUrl,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      category: data['category'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'category': category,
      'photoUrl': photoUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}

/// Service pour gérer les utilisateurs
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Obtient l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Obtient l'UID de l'utilisateur actuel
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Stream pour l'utilisateur actuel
  Stream<UserModel?> get currentUserStream {
    final uid = currentUserUid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  /// Récupère un utilisateur par UID
  Future<UserModel?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur: $e');
      return null;
    }
  }

  /// Récupère la catégorie de l'utilisateur actuel
  Future<String?> getCurrentUserCategory() async {
    try {
      final user = await getUserByUid(currentUserUid ?? '');
      return user?.category;
    } catch (e) {
      print('Erreur lors de la récupération de la catégorie: $e');
      return null;
    }
  }

  /// Stream pour la catégorie de l'utilisateur actuel
  Stream<String?> get currentUserCategoryStream {
    return currentUserStream.map((user) => user?.category);
  }

  /// Met à jour la catégorie de l'utilisateur
  Future<void> updateUserCategory(String category) async {
    try {
      final uid = currentUserUid;
      if (uid == null) throw Exception('Utilisateur non connecté');
      await _firestore.collection('users').doc(uid).update({
        'category': category,
      });
    } catch (e) {
      print('Erreur lors de la mise à jour de la catégorie: $e');
      rethrow;
    }
  }

  /// Crée ou met à jour le profil utilisateur
  Future<void> createOrUpdateProfile({
    required String displayName,
    String? photoUrl,
    String? category,
  }) async {
    try {
      final uid = currentUserUid;
      if (uid == null) throw Exception('Utilisateur non connecté');
      
      await _firestore.collection('users').doc(uid).set({
        'email': currentUser?.email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Erreur lors de la création/mise à jour du profil: $e');
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }
}
