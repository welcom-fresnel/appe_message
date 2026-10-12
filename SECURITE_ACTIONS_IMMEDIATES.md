# 🚀 Actions de Sécurité Immédiates - Guide Pratique

## 📌 À Faire MAINTENANT (Priorité 1 - Critique)

### 1. Mettre à jour Firestore Rules ⚠️

**Fichier** : `hermin/firestore.rules`

Ajouter ces règles manquantes pour les conversations :

```javascript
// À AJOUTER après la ligne 153 (avant la fermeture finale)

// ========== CONVERSATIONS ==========
match /conversations/{conversationId} {
  allow read: if isSignedIn() 
    && request.auth.uid in resource.data.participants;
  
  allow create: if isSignedIn() 
    && request.auth.uid in request.resource.data.participants
    && request.resource.data.participants.size() == 2;
  
  allow update: if isSignedIn() 
    && request.auth.uid in resource.data.participants
    && request.resource.data.participants == resource.data.participants; // Empêcher changement participants
  
  allow delete: if false; // Jamais supprimer via client
  
  // Messages dans conversations
  match /messages/{messageId} {
    allow read: if isSignedIn() 
      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
    
    allow create: if isSignedIn() 
      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
      && request.resource.data.senderId == request.auth.uid
      && request.resource.data.text is string
      && request.resource.data.text.size() <= 5000;
    
    allow update, delete: if false; // Messages immuables
  }
}

// ========== SENT_MESSAGES_HISTORY (Admin seulement) ==========
match /sent_messages_history/{docId} {
  allow create: if isAdmin() && request.resource.data.adminId == request.auth.uid;
  allow read: if isAdmin();
  allow update, delete: if false; // Historique immuable
}
```

**Déployer** :

```bash
cd hermin
firebase deploy --only firestore:rules
```

### 2. Créer Firebase Storage Rules ⚠️

**Créer le fichier** : `hermin/storage.rules`

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isValidSize() {
      return request.resource.size < 10 * 1024 * 1024; // 10MB max
    }
    
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    // Tout est bloqué par défaut (vous utilisez Cloudinary)
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

**Déployer** :

```bash
firebase deploy --only storage
```

### 3. Sécuriser `.gitignore` ⚠️

**Vérifier que ces lignes sont présentes** dans `hermin/.gitignore` et `hermine_admin/.gitignore` :

```gitignore
# SECRETS - NE JAMAIS COMMITTER
.env
.env.*
!.env.example
environments/.env.*
!environments/.env.*.example

# Firebase
**/google-services.json
**/GoogleService-Info.plist
firebase_options.dart

# Clés Android
android/key.properties
android/app/upload-keystore.jks
android/app/*.jks
android/app/*.keystore

# Config
lib/config.dart
lib/secrets.dart
```

**Vérifier l'historique Git** :

```bash
# Si des secrets ont été commités par erreur
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch environments/.env.clientA" \
  --prune-empty --tag-name-filter cat -- --all
```

### 4. Activer Email Verification 🔒

**Fichier** : `hermin/lib/screens/auth_screen.dart`

**Modifier la fonction `_signUp` (ligne 79)** :

```dart
Future<void> _signUp() async {
  if (!_formKey.currentState!.validate()) return;
  if (_category == null) {
    setState(() => _error = 'Sélectionne ta catégorie');
    return;
  }
  if (_passwordController.text != _confirmPasswordController.text) {
    setState(() => _error = 'Les mots de passe ne correspondent pas');
    return;
  }

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = credential.user;
    if (user != null) {
      // ✅ AJOUTER CES LIGNES
      // Envoyer email de vérification
      await user.sendEmailVerification();
      
      // Créer le profil utilisateur
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'category': _category,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emailVerified': false, // ✅ AJOUTER
      });
      
      // ✅ AJOUTER : Déconnecter jusqu'à vérification
      await FirebaseAuth.instance.signOut();
      
      // ✅ AJOUTER : Message de confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✉️ Email de vérification envoyé ! Vérifie ta boîte mail.'),
            duration: Duration(seconds: 5),
          ),
        );
        setState(() => _isSignUp = false); // Retour à l'écran de connexion
      }
    }
  } on FirebaseAuthException catch (e) {
    setState(() => _error = _friendlyAuthError(e, isSignUp: true));
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

**Modifier la fonction `_signIn` (ligne 50)** :

```dart
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
    
    final user = FirebaseAuth.instance.currentUser;
    
    // ✅ AJOUTER : Vérifier email
    if (user != null && !user.emailVerified) {
      await FirebaseAuth.instance.signOut();
      setState(() => _error = 
        '✉️ Email non vérifié. Vérifie ta boîte mail ou renvoie l\'email de vérification.');
      return;
    }
    
    // Mettre à jour last login
    final uid = user?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'emailVerified': true, // ✅ AJOUTER
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  } on FirebaseAuthException catch (e) {
    setState(() => _error = _friendlyAuthError(e));
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

### 5. Renforcer Validation Mot de Passe 🔑

**Fichier** : `hermin/lib/screens/auth_screen.dart`

**Ajouter cette fonction dans la classe `_AuthScreenState`** :

```dart
String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Mot de passe requis';
  }
  if (value.length < 8) {
    return 'Minimum 8 caractères';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Au moins 1 majuscule requise';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Au moins 1 chiffre requis';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Au moins 1 caractère spécial requis (!@#$%...)';
  }
  return null;
}
```

**Utiliser dans le TextFormField** du mot de passe (chercher `_passwordController` dans le code) :

```dart
TextFormField(
  controller: _passwordController,
  obscureText: _obscure,
  validator: _validatePassword, // ✅ AJOUTER
  decoration: InputDecoration(
    labelText: _isSignUp ? 'Mot de passe (min 8 caractères, 1 maj, 1 chiffre, 1 spécial)' : 'Mot de passe',
    // ... reste
  ),
)
```

---

## 📌 À Faire CETTE SEMAINE (Priorité 2 - Important)

### 6. Créer Service de Validation

**Créer le fichier** : `hermin/lib/services/validation_service.dart`

```dart
class ValidationService {
  static const int MAX_TEXT_LENGTH = 10000;
  static const int MAX_USERNAME_LENGTH = 50;
  
  static String? sanitizeText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    
    String cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    if (cleaned.length > MAX_TEXT_LENGTH) {
      cleaned = cleaned.substring(0, MAX_TEXT_LENGTH);
    }
    
    return cleaned;
  }
  
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
  
  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);
  }
  
  static bool containsSuspiciousContent(String text) {
    final suspiciousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'SELECT\s+.*FROM', caseSensitive: false),
      RegExp(r'DROP\s+TABLE', caseSensitive: false),
    ];
    
    return suspiciousPatterns.any((pattern) => pattern.hasMatch(text));
  }
}
```

**Utiliser dans** `feed_screen.dart` (lors de création de post) :

```dart
Future<void> _createPost() async {
  // ✅ AJOUTER validation
  final text = ValidationService.sanitizeText(_textCtrl.text);
  
  if (text != null && ValidationService.containsSuspiciousContent(text)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚠️ Contenu suspect détecté')),
    );
    return;
  }
  
  // ... reste du code de création
}
```

### 7. Activer Firebase App Check

**Dans Firebase Console** :
1. Aller dans Project Settings → App Check
2. Cliquer "Register" pour votre app Android
3. Choisir "Play Integrity" (production) ou "Debug" (développement)
4. Copier le debug token si en dev

**Dans le code** - `hermin/lib/main.dart` et `hermine_admin/lib/main.dart` :

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  await dotenv.load(fileName: 'environments/.env.$flavor');

  await Firebase.initializeApp();
  
  // ✅ AJOUTER App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, // En dev
    // androidProvider: AndroidProvider.playIntegrity, // En production
  );

  await FirebaseService.instance.initialize();
  await NotificationHandler.instance.initialize();
  runApp(const MyApp());
}
```

**Ajouter le package** dans `pubspec.yaml` :

```yaml
dependencies:
  firebase_app_check: ^0.2.1+7
```

### 8. Network Security Config (Android)

**Créer** : `hermin/android/app/src/main/res/xml/network_security_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">firebaseio.com</domain>
        <domain includeSubdomains="true">cloudinary.com</domain>
        <domain includeSubdomains="true">googleapis.com</domain>
    </domain-config>
</network-security-config>
```

**Modifier** : `hermin/android/app/src/main/AndroidManifest.xml`

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:label="@string/app_name"
    ...>
```

### 9. Ajouter Crashlytics

**Dans Firebase Console** :
1. Aller dans Release & Monitor → Crashlytics
2. Activer Crashlytics

**Ajouter le package** dans `pubspec.yaml` :

```yaml
dependencies:
  firebase_crashlytics: ^3.4.9
```

**Dans** `main.dart` :

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  await dotenv.load(fileName: 'environments/.env.$flavor');

  await Firebase.initializeApp();
  
  // ✅ AJOUTER Crashlytics (production seulement)
  if (kReleaseMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await FirebaseService.instance.initialize();
  await NotificationHandler.instance.initialize();
  runApp(const MyApp());
}
```

---

## 📌 À Faire CE MOIS-CI (Priorité 3 - Recommandé)

### 10. Implémenter Rate Limiting

**Créer** : `hermin/lib/services/rate_limiter_service.dart`

```dart
class RateLimiterService {
  static final _timestamps = <String, List<DateTime>>{};
  
  static bool checkRateLimit(String action, {int maxAttempts = 5, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final key = action;
    
    // Récupérer timestamps
    final timestamps = _timestamps[key] ?? [];
    
    // Filtrer dans la fenêtre
    final recentTimestamps = timestamps.where((t) => now.difference(t) < window).toList();
    
    if (recentTimestamps.length >= maxAttempts) {
      return false; // Rate limit dépassé
    }
    
    recentTimestamps.add(now);
    _timestamps[key] = recentTimestamps;
    
    return true;
  }
  
  static void reset(String action) {
    _timestamps.remove(action);
  }
}
```

**Utiliser dans** `auth_screen.dart` :

```dart
Future<void> _signIn() async {
  // ✅ AJOUTER rate limiting
  if (!RateLimiterService.checkRateLimit('login', maxAttempts: 5)) {
    setState(() => _error = '⚠️ Trop de tentatives. Réessaye dans 1 minute.');
    return;
  }
  
  // ... reste du code
}
```

### 11. Configurer ProGuard (Android Obfuscation)

**Créer** : `hermin/android/app/proguard-rules.pro`

```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Cloudinary
-keep class com.cloudinary.** { *; }
```

**Modifier** : `hermin/android/app/build.gradle.kts`

```kotlin
buildTypes {
    release {
        // ✅ AJOUTER
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### 12. Logs de Sécurité

**Créer** : `hermin/lib/services/logger_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error, security }

class LoggerService {
  static Future<void> log({
    required LogLevel level,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // Debug mode: juste print
    if (!kReleaseMode) {
      debugPrint('[$level] $message');
      return;
    }
    
    try {
      await FirebaseFirestore.instance.collection('app_logs').add({
        'level': level.name,
        'message': message,
        'data': data,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Erreur logging: $e');
    }
  }
  
  static Future<void> logSecurityEvent({
    required String event,
    Map<String, dynamic>? details,
  }) async {
    await log(
      level: LogLevel.security,
      message: event,
      data: details,
    );
  }
}
```

**Utiliser lors d'événements de sécurité** :

```dart
// Tentative de connexion échouée
await LoggerService.logSecurityEvent(
  event: 'failed_login',
  details: {'email': email, 'error': e.code},
);

// Accès non autorisé
await LoggerService.logSecurityEvent(
  event: 'unauthorized_access',
  details: {'resource': 'admin_panel'},
);
```

---

## ✅ Checklist Rapide

### Critique (Aujourd'hui)
- [ ] Déployer Firestore Rules mises à jour
- [ ] Déployer Storage Rules
- [ ] Vérifier `.gitignore` (secrets)
- [ ] Activer email verification
- [ ] Renforcer validation mot de passe

### Important (Cette semaine)
- [ ] Créer service de validation
- [ ] Activer Firebase App Check
- [ ] Configurer Network Security (Android)
- [ ] Ajouter Crashlytics

### Recommandé (Ce mois)
- [ ] Implémenter rate limiting
- [ ] Configurer ProGuard
- [ ] Ajouter logs de sécurité
- [ ] Tester sur appareil réel

---

## 🚀 Commandes Rapides

### Déployer Rules
```bash
cd hermin
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### Build Sécurisé
```bash
# Android
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# iOS
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
```

### Tester Rules
```bash
firebase emulators:start --only firestore
```

---

## 📞 Besoin d'Aide ?

Si un point n'est pas clair :
1. Consulter `GUIDE_SECURITE_COMPLET.md` pour les détails
2. Firebase Console → Documentation
3. Flutter Security Best Practices

**Bon courage champion ! 🛡️**

