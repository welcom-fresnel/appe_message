import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/components/app_button.dart';
import '../ui/components/app_card.dart';
import '../ui/components/state_widgets.dart';
import '../ui/components/app_text_field.dart';

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
  String? _category;

  String _friendlyAuthError(FirebaseAuthException e, {bool isSignUp = false}) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Connexion impossible. Verifie ta connexion internet et reessaie.';
      case 'invalid-credential':
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessaie dans quelques instants.';
      case 'email-already-in-use':
        return isSignUp
            ? 'Cet email est deja utilise. Connecte-toi ou choisis un autre email.'
            : 'Email deja utilise.';
      case 'weak-password':
        return 'Mot de passe trop faible. Utilise au moins 6 caracteres.';
      default:
        return isSignUp ? 'Creation du compte impossible. Reessaie.' : 'Connexion impossible. Reessaie.';
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
    } on FirebaseException {
      setState(() => _error = 'Connexion impossible. Verifie ta connexion internet et reessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      setState(() => _error = 'Veuillez choisir une categorie');
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

      final keywords = <String>{};
      if (first.isNotEmpty) {
        for (int i = 1; i <= first.length; i++) {
          keywords.add(first.toLowerCase().substring(0, i));
        }
      }
      if (last.isNotEmpty) {
        for (int i = 1; i <= last.length; i++) {
          keywords.add(last.toLowerCase().substring(0, i));
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'username': display.isNotEmpty ? display : _emailController.text.trim(),
        'firstName': first,
        'lastName': last,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'category': _category,
        'role': _category,
        'photoUrl': user.photoURL,
        'keywords': keywords.toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'fcmToken': null,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e, isSignUp: true));
    } on FirebaseException {
      setState(() => _error = 'Creation du compte impossible. Verifie ta connexion internet et reessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entrez votre email pour reinitialiser le mot de passe');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email de reinitialisation envoye')));
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_isSignUp ? 'Creer un compte' : 'Connexion', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Bienvenue sur LEAURRY-FLORIDE', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        if (_isSignUp) ...[
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _firstNameController,
                                  label: 'Prenom',
                                  prefix: const Icon(Icons.person_outline),
                                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  controller: _lastNameController,
                                  label: 'Nom',
                                  prefix: const Icon(Icons.badge_outlined),
                                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AppTextField(controller: _phoneController, label: 'Telephone (optionnel)', prefix: const Icon(Icons.phone_outlined), keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                        ],
                        AppTextField(
                          controller: _emailController,
                          label: 'Email',
                          prefix: const Icon(Icons.alternate_email),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _passwordController,
                          label: 'Mot de passe',
                          obscureText: _obscure,
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                          validator: (v) => v == null || v.length < 6 ? 'Min 6 caracteres' : null,
                        ),
                        if (_isSignUp) ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirmer le mot de passe',
                            obscureText: _obscure,
                            prefix: const Icon(Icons.password_outlined),
                            validator: (v) => v != _passwordController.text ? 'Ne correspond pas' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(labelText: 'Categorie', prefixIcon: Icon(Icons.group_outlined)),
                            items: const [
                              DropdownMenuItem(value: 'parent', child: Text('Parent')),
                              DropdownMenuItem(value: 'eleve', child: Text('Eleve')),
                            ],
                            onChanged: (v) => setState(() => _category = v),
                            validator: (v) => v == null ? 'Requis' : null,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _loading ? null : _resetPassword, child: const Text('Mot de passe oublie ?')),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          AppErrorState(message: _error!),
                        ],
                        const SizedBox(height: 12),
                        AppButton(
                          label: _isSignUp ? 'Creer mon compte' : 'Se connecter',
                          onPressed: _loading ? null : () => _isSignUp ? _signUp() : _signIn(),
                          loading: _loading,
                          size: AppButtonSize.lg,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null;
                                  }),
                          child: Text(_isSignUp ? 'J\'ai deja un compte' : 'Creer un compte'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}






