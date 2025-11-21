import 'package:firebase_auth/firebase_auth.dart';

/// Service pour gérer l'authentification
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  /// Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// UID de l'utilisateur actuel
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Vérifier si l'utilisateur est connecté
  bool get isAuthenticated => _auth.currentUser != null;

  /// Inscription avec email et mot de passe
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  /// Connexion avec email et mot de passe
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Erreur lors de la connexion: $e');
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

  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Erreur lors de la réinitialisation: $e');
      rethrow;
    }
  }

  /// Mettre à jour le profil
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isNotEmpty) {
        await user.updateDisplayName(displayName);
        if (photoUrl != null) {
          await user.updatePhotoURL(photoUrl);
        }
        await user.reload();
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      rethrow;
    }
  }

  /// Vérifier l'email
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      await user.sendEmailVerification();
    } catch (e) {
      print('Erreur lors de l\'envoi de la vérification: $e');
      rethrow;
    }
  }

  /// Vérifier si l'email est vérifié
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
}
