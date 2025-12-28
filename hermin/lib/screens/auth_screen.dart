import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _isSignUp = false;
  String? _category; // 'parent' | 'élève'

  String _friendlyAuthError(FirebaseAuthException e, {bool isSignUp = false}) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Connexion impossible. Vérifie ta connexion internet et réessaie.';
      case 'invalid-credential':
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie dans quelques instants.';
      case 'email-already-in-use':
        return isSignUp
            ? 'Cet email est déjà utilisé. Connecte-toi ou choisis un autre email.'
            : 'Email déjà utilisé.';
      case 'weak-password':
        return 'Mot de passe trop faible. Utilise au moins 6 caractères.';
      default:
        return isSignUp
            ? 'Création du compte impossible. Réessaie.'
            : 'Connexion impossible. Réessaie.';
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } on FirebaseException catch (_) {
      setState(
        () => _error =
            'Connexion impossible. Vérifie ta connexion internet et réessaie.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      setState(() => _error = 'Veuillez choisir une catégorie');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = cred.user!;
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final display = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
      if (display.isNotEmpty) {
        await user.updateDisplayName(display);
      }
      final uid = user.uid;

      // Générer les keywords pour la recherche
      final keywords = <String>{};
      if (first.isNotEmpty) {
        keywords.add(first.toLowerCase());
        for (int i = 1; i <= first.length; i++) {
          keywords.add(first.toLowerCase().substring(0, i));
        }
      }
      if (last.isNotEmpty) {
        keywords.add(last.toLowerCase());
        for (int i = 1; i <= last.length; i++) {
          keywords.add(last.toLowerCase().substring(0, i));
        }
      }
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) {
        keywords.add(phone);
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'username': display.isNotEmpty ? display : _emailController.text.trim(),
        'firstName': first,
        'lastName': last,
        'email': _emailController.text.trim(),
        'phone': phone.isEmpty ? null : phone,
        'category': _category,
        'role': _category,
        'photoUrl': user.photoURL,
        'keywords': keywords.toList(), // Pour la recherche
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'fcmToken': null,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e, isSignUp: true));
    } on FirebaseException catch (_) {
      setState(
        () => _error =
            'Création du compte impossible. Vérifie ta connexion internet et réessaie.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _error = 'Entrez votre email pour réinitialiser le mot de passe',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de réinitialisation envoyé')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LEAURRY-FLORIDE')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 80.0),
              child: Text(
                _isSignUp ? "Créer un compte" : "Connexion...",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                  shadows: [
                    Shadow(
                      color: Colors.white,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        if (_isSignUp) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                      Icons.person,
                                      color: Color(0xFF1976D2),
                                    ),
                                    labelText: 'Prénom',
                                    filled: true,
                                    fillColor: const Color(0xFFE3F2FD),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.isEmpty ? 'Requis' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF1976D2),
                                    ),
                                    labelText: 'Nom',
                                    filled: true,
                                    fillColor: const Color(0xFFE3F2FD),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.isEmpty ? 'Requis' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFF1976D2),
                              ),
                              labelText: 'Téléphone (optionnel)',
                              filled: true,
                              fillColor: const Color(0xFFE3F2FD),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.email,
                              color: Color(0xFF1976D2),
                            ),
                            labelText: 'Email',
                            filled: true,
                            fillColor: const Color(0xFFE3F2FD),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Color(0xFF1976D2),
                            ),
                            labelText: 'Mot de passe',
                            filled: true,
                            fillColor: const Color(0xFFE3F2FD),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF1976D2),
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          validator: (v) => v == null || v.length < 6
                              ? 'Min 6 caractères'
                              : null,
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF1976D2),
                              ),
                              labelText: 'Confirmer le mot de passe',
                              filled: true,
                              fillColor: const Color(0xFFE3F2FD),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            obscureText: _obscure,
                            validator: (v) => v != _passwordController.text
                                ? 'Ne correspond pas'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _category,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.group,
                                color: Color(0xFF1976D2),
                              ),
                              labelText: 'Catégorie',
                              filled: true,
                              fillColor: const Color(0xFFE3F2FD),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'parent',
                                child: Text('Parent'),
                              ),
                              DropdownMenuItem(
                                value: 'eleve',
                                child: Text('Élève'),
                              ), // <-- 'eleve' sans accent
                            ],
                            onChanged: (v) => setState(() => _category = v),
                            validator: (v) => v == null ? 'Requis' : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Ne pas oublier',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _loading ? null : _resetPassword,
                              child: const Text(
                                'Mot de passe oublié ?',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () => _isSignUp ? _signUp() : _signIn(),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isSignUp
                                        ? 'Créer mon compte'
                                        : 'Se connecter',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null;
                                  });
                                },
                          child: Text(
                            _isSignUp
                                ? 'J\'ai déjà un compte'
                                : 'Créer un compte',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
