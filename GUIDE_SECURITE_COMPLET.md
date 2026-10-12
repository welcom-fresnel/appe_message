# 🔒 Guide Complet de Sécurisation des Applications

## Vue d'ensemble

Ce guide couvre la sécurisation de vos deux applications :
- **`hermin`** : Application mobile utilisateur (parents, élèves, enseignants)
- **`hermine_admin`** : Application mobile administration

---

## 📋 Table des Matières

1. [Sécurité Firebase](#1-sécurité-firebase)
2. [Authentification & Autorisation](#2-authentification--autorisation)
3. [Validation des Données](#3-validation-des-données)
4. [Sécurité des API & Services](#4-sécurité-des-api--services)
5. [Protection des Secrets](#5-protection-des-secrets)
6. [Sécurité Réseau](#6-sécurité-réseau)
7. [Sécurité du Code](#7-sécurité-du-code)
8. [Rate Limiting & Protection DDoS](#8-rate-limiting--protection-ddos)
9. [Logs & Monitoring](#9-logs--monitoring)
10. [Checklist de Déploiement](#10-checklist-de-déploiement)

---

## 1. Sécurité Firebase

### 1.1 Firestore Security Rules ✅ (Déjà en place)

Vos règles actuelles sont **bonnes** mais peuvent être améliorées :

#### Points Forts Actuels :
- ✅ Authentification requise pour toutes les opérations
- ✅ Fonction `isAdmin()` pour vérifier les rôles
- ✅ Validation des propriétaires pour les posts/comments/likes
- ✅ Protection contre l'auto-promotion en admin (`allow write: if false` pour `/admins`)

#### Améliorations Recommandées :

**A. Ajouter des validations de taille**

```javascript
// Dans firestore.rules, ajouter avant les match patterns
function isValidText(text) {
  return text is string 
    && text.size() >= 1 
    && text.size() <= 10000; // Max 10k caractères
}

function isValidImageUrl(url) {
  return url is string 
    && url.size() <= 2048 
    && url.matches('https://.*');
}

// Utiliser dans les règles posts
match /posts/{postId} {
  allow create: if isSignedIn() 
    && request.resource.data.userId == request.auth.uid
    && isValidText(request.resource.data.text)
    && (!request.resource.data.keys().hasAny(['mediaUrls']) 
        || request.resource.data.mediaUrls.size() <= 10); // Max 10 images
  // ...
}
```

**B. Limiter les conversations**

```javascript
// Ajouter pour conversations (manquant actuellement)
match /conversations/{conversationId} {
  allow read: if isSignedIn() 
    && request.auth.uid in resource.data.participants;
  
  allow create: if isSignedIn() 
    && request.auth.uid in request.resource.data.participants
    && request.resource.data.participants.size() == 2; // Seulement 1-to-1
  
  allow update: if isSignedIn() 
    && request.auth.uid in resource.data.participants;
  
  allow delete: if false; // Ne jamais supprimer via client
  
  // Messages dans les conversations
  match /messages/{messageId} {
    allow read: if isSignedIn() 
      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
    
    allow create: if isSignedIn() 
      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
      && request.resource.data.senderId == request.auth.uid
      && isValidText(request.resource.data.text);
    
    allow update, delete: if false; // Messages immuables
  }
}
```

**C. Protection reception (messages vers admin)**

```javascript
match /reception/{docId} {
  // N'importe qui peut créer (pour contact form)
  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid
    && isValidText(request.resource.data.message)
    && request.resource.data.keys().hasAll(['userId', 'message', 'createdAt']);
  
  // Seuls admins peuvent lire/modifier
  allow read, update: if isAdmin();
  
  // Empêcher suppression côté client
  allow delete: if false;
}
```

**D. Protection sent_messages_history**

```javascript
match /sent_messages_history/{docId} {
  allow create: if isAdmin() 
    && request.resource.data.adminId == request.auth.uid;
  
  allow read: if isAdmin();
  
  allow update, delete: if false; // Historique immuable
}
```

### 1.2 Firebase Storage Rules

Créer `storage.rules` :

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isSignedIn() && 
        firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == "admin";
    }
    
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    function isAudio() {
      return request.resource.contentType.matches('audio/.*');
    }
    
    function isValidSize() {
      // Max 10MB pour images, 5MB pour audio
      return (isImage() && request.resource.size < 10 * 1024 * 1024)
        || (isAudio() && request.resource.size < 5 * 1024 * 1024);
    }
    
    // Images de profil
    match /profile_images/{userId}/{fileName} {
      allow read: if true; // Public
      allow write: if isSignedIn() 
        && request.auth.uid == userId
        && isImage()
        && isValidSize();
    }
    
    // Images de posts
    match /post_images/{userId}/{fileName} {
      allow read: if true; // Public
      allow write: if isSignedIn() 
        && request.auth.uid == userId
        && isImage()
        && isValidSize();
    }
    
    // Audio messages (admin seulement)
    match /audio_messages/{fileName} {
      allow read: if isSignedIn(); // Authentifié
      allow write: if isAdmin() 
        && isAudio()
        && isValidSize();
    }
    
    // Bloquer tout le reste
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### 1.3 Realtime Database Rules (si utilisé)

```json
{
  "rules": {
    ".read": false,
    ".write": false,
    "users": {
      "$uid": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid === $uid"
      }
    }
  }
}
```

---

## 2. Authentification & Autorisation

### 2.1 Renforcer l'Authentification

#### A. Validation des Mots de Passe Côté Client

Dans `auth_screen.dart`, ajouter une validation stricte :

```dart
String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Le mot de passe est requis';
  }
  if (value.length < 8) {
    return 'Minimum 8 caractères';
  }
  // Au moins une majuscule
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Au moins une majuscule requise';
  }
  // Au moins un chiffre
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Au moins un chiffre requis';
  }
  // Au moins un caractère spécial
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Au moins un caractère spécial requis';
  }
  return null;
}
```

#### B. Limiter les Tentatives de Connexion

```dart
class _AuthScreenState extends State<AuthScreen> {
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;
  
  Future<void> _signIn() async {
    // Vérifier le rate limiting
    if (_failedAttempts >= 5) {
      final now = DateTime.now();
      if (_lastFailedAttempt != null) {
        final diff = now.difference(_lastFailedAttempt!);
        if (diff.inMinutes < 5) {
          setState(() => _error = 
            'Trop de tentatives. Réessayez dans ${5 - diff.inMinutes} minutes.');
          return;
        } else {
          _failedAttempts = 0; // Reset après 5 minutes
        }
      }
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Succès : reset compteur
      _failedAttempts = 0;
      _lastFailedAttempt = null;
      
      // Log connexion réussie
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastLoginIp': await _getDeviceInfo(), // Optionnel
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();
      
      // Log tentative échouée (optionnel, mais utile pour détecter attaques)
      _logFailedAttempt(_emailController.text.trim());
      
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Future<String> _getDeviceInfo() async {
    // Implémenter avec device_info_plus package
    return 'device_info';
  }
  
  void _logFailedAttempt(String email) {
    FirebaseFirestore.instance.collection('auth_logs').add({
      'email': email,
      'type': 'failed_login',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
```

#### C. Vérification Email Obligatoire

```dart
Future<void> _signUp() async {
  // ... après createUserWithEmailAndPassword
  
  final user = credential.user;
  if (user != null && !user.emailVerified) {
    await user.sendEmailVerification();
    
    // Déconnecter jusqu'à vérification
    await FirebaseAuth.instance.signOut();
    
    setState(() => _error = 
      '✉️ Email de vérification envoyé. Vérifie ta boîte mail avant de te connecter.');
  }
}

Future<void> _signIn() async {
  // ... après signInWithEmailAndPassword
  
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.emailVerified) {
    await FirebaseAuth.instance.signOut();
    setState(() => _error = 
      'Email non vérifié. Vérifie ta boîte mail.');
    return;
  }
}
```

### 2.2 Gestion des Rôles Admin

#### A. Utiliser Firebase Custom Claims (RECOMMANDÉ)

**Cloud Function** (`functions/src/index.ts`) :

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// Fonction pour promouvoir un utilisateur en admin
export const setAdminClaim = functions.https.onCall(async (data, context) => {
  // Vérifier que l'appelant est déjà admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Seuls les admins peuvent promouvoir d\'autres admins'
    );
  }
  
  const { uid } = data;
  
  if (!uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID requis'
    );
  }
  
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    
    // Log dans Firestore
    await admin.firestore().collection('admin_actions').add({
      action: 'promote_admin',
      targetUid: uid,
      performedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return { success: true, message: `Utilisateur ${uid} promu admin` };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Erreur lors de la promotion');
  }
});

// Fonction pour révoquer les droits admin
export const revokeAdminClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Seuls les admins peuvent révoquer des droits'
    );
  }
  
  const { uid } = data;
  
  // Empêcher l'auto-révocation
  if (uid === context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Impossible de révoquer ses propres droits'
    );
  }
  
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: false });
    
    await admin.firestore().collection('admin_actions').add({
      action: 'revoke_admin',
      targetUid: uid,
      performedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return { success: true, message: `Droits admin révoqués pour ${uid}` };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Erreur lors de la révocation');
  }
});
```

**Mettre à jour Firestore Rules** :

```javascript
function isAdmin() {
  return request.auth != null && request.auth.token.admin == true;
}
```

#### B. Côté App - Vérifier les Claims

```dart
// services/admin_service.dart
class AdminService {
  static Future<bool> isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims?['admin'] == true;
  }
  
  static Future<void> promoteToAdmin(String uid) async {
    final callable = FirebaseFunctions.instance.httpsCallable('setAdminClaim');
    await callable.call({'uid': uid});
  }
  
  static Future<void> revokeAdmin(String uid) async {
    final callable = FirebaseFunctions.instance.httpsCallable('revokeAdminClaim');
    await callable.call({'uid': uid});
  }
}
```

---

## 3. Validation des Données

### 3.1 Input Sanitization

Créer un service de validation :

```dart
// lib/services/validation_service.dart
import 'package:flutter/foundation.dart';

class ValidationService {
  static const int MAX_TEXT_LENGTH = 10000;
  static const int MAX_USERNAME_LENGTH = 50;
  static const int MAX_IMAGES = 10;
  
  /// Nettoyer et valider un texte
  static String? sanitizeText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    
    // Enlever espaces multiples
    String cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Limiter la longueur
    if (cleaned.length > MAX_TEXT_LENGTH) {
      cleaned = cleaned.substring(0, MAX_TEXT_LENGTH);
    }
    
    // Échapper HTML/JS (basique)
    cleaned = cleaned
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
    
    return cleaned;
  }
  
  /// Valider un email
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }
  
  /// Valider un numéro de téléphone (format international)
  static bool isValidPhone(String phone) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);
  }
  
  /// Valider une URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isScheme('HTTPS') || uri.isScheme('HTTP');
    } catch (e) {
      return false;
    }
  }
  
  /// Valider une URL Cloudinary spécifiquement
  static bool isValidCloudinaryUrl(String url) {
    return url.startsWith('https://res.cloudinary.com/');
  }
  
  /// Détecter du contenu suspect (SQL injection, XSS)
  static bool containsSuspiciousContent(String text) {
    final suspiciousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false), // onclick=, onerror=
      RegExp(r'SELECT\s+.*FROM', caseSensitive: false),
      RegExp(r'DROP\s+TABLE', caseSensitive: false),
      RegExp(r'INSERT\s+INTO', caseSensitive: false),
      RegExp(r'DELETE\s+FROM', caseSensitive: false),
    ];
    
    return suspiciousPatterns.any((pattern) => pattern.hasMatch(text));
  }
  
  /// Filtrer les mots interdits (profanité basique)
  static String filterProfanity(String text) {
    final badWords = [
      'mot1', 'mot2', // Ajouter vos mots interdits
    ];
    
    String filtered = text;
    for (final word in badWords) {
      filtered = filtered.replaceAll(
        RegExp(word, caseSensitive: false),
        '*' * word.length,
      );
    }
    
    return filtered;
  }
}
```

### 3.2 Utiliser la Validation

```dart
// Dans feed_screen.dart
Future<void> _createPost() async {
  final text = ValidationService.sanitizeText(_textCtrl.text);
  
  if (text != null && ValidationService.containsSuspiciousContent(text)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contenu suspect détecté')),
    );
    return;
  }
  
  // Filtrer profanité
  final cleanedText = text != null ? ValidationService.filterProfanity(text) : null;
  
  // Valider les URLs d'images
  for (final url in mediaUrls) {
    if (!ValidationService.isValidCloudinaryUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL d\'image invalide')),
      );
      return;
    }
  }
  
  // Créer le post...
}
```

---

## 4. Sécurité des API & Services

### 4.1 Cloudinary - Sécuriser les Uploads

#### A. Signed Uploads (RECOMMANDÉ)

**Cloud Function** :

```typescript
export const generateCloudinarySignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentification requise');
  }
  
  const crypto = require('crypto');
  const timestamp = Math.round(Date.now() / 1000);
  
  const params = {
    timestamp: timestamp,
    upload_preset: functions.config().cloudinary.upload_preset,
    folder: data.folder || 'uploads',
  };
  
  // Créer la signature
  const paramsString = Object.keys(params)
    .sort()
    .map(key => `${key}=${params[key]}`)
    .join('&');
  
  const signature = crypto
    .createHash('sha1')
    .update(paramsString + functions.config().cloudinary.api_secret)
    .digest('hex');
  
  return {
    signature,
    timestamp,
    api_key: functions.config().cloudinary.api_key,
    upload_preset: params.upload_preset,
    folder: params.folder,
  };
});
```

**Côté Client** :

```dart
// services/cloudinary_service.dart
Future<String?> uploadImageSecure(File imageFile) async {
  try {
    // 1. Obtenir signature depuis Cloud Function
    final callable = FirebaseFunctions.instance
        .httpsCallable('generateCloudinarySignature');
    final result = await callable.call({'folder': 'post_images'});
    
    final signature = result.data['signature'];
    final timestamp = result.data['timestamp'];
    final apiKey = result.data['api_key'];
    final uploadPreset = result.data['upload_preset'];
    final folder = result.data['folder'];
    
    // 2. Upload avec signature
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/${dotenv.env['CLOUDINARY_CLOUD_NAME']}/image/upload',
    );
    
    final request = http.MultipartRequest('POST', url)
      ..fields['timestamp'] = timestamp.toString()
      ..fields['signature'] = signature
      ..fields['api_key'] = apiKey
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    
    final response = await request.send();
    
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      return data['secure_url'];
    }
    
    return null;
  } catch (e) {
    debugPrint('Erreur upload Cloudinary: $e');
    return null;
  }
}
```

#### B. Configurer Cloudinary pour Bloquer Uploads Non Signés

Dans le dashboard Cloudinary :
1. Settings → Security
2. **Unsigned uploads** : Cocher "Restrict uploads to signed only"
3. **Allowed fetch domains** : Ajouter seulement vos domaines
4. **Auto moderation** : Activer pour détecter contenu inapproprié

### 4.2 SMS Service - Rate Limiting

```dart
// services/sms_service.dart (hermine_admin)
class SmsService {
  static const int MAX_SMS_PER_HOUR = 100;
  static const int MAX_SMS_PER_DAY = 1000;
  
  static Future<bool> canSendSms() async {
    final now = DateTime.now();
    final hourAgo = now.subtract(const Duration(hours: 1));
    final dayAgo = now.subtract(const Duration(hours: 24));
    
    // Compter SMS envoyés dans la dernière heure
    final hourCount = await FirebaseFirestore.instance
        .collection('sms_logs')
        .where('sentAt', isGreaterThan: hourAgo)
        .count()
        .get();
    
    if (hourCount.count >= MAX_SMS_PER_HOUR) {
      return false;
    }
    
    // Compter SMS envoyés dans les dernières 24h
    final dayCount = await FirebaseFirestore.instance
        .collection('sms_logs')
        .where('sentAt', isGreaterThan: dayAgo)
        .count()
        .get();
    
    return dayCount.count < MAX_SMS_PER_DAY;
  }
  
  static Future<int> sendBatchSms({
    required List<String> phones,
    required String message,
  }) async {
    if (!await canSendSms()) {
      throw Exception('Limite d\'envoi SMS atteinte');
    }
    
    // Valider les numéros
    final validPhones = phones
        .where((p) => ValidationService.isValidPhone(p))
        .toList();
    
    if (validPhones.isEmpty) {
      throw Exception('Aucun numéro valide');
    }
    
    // Sanitizer le message
    final cleanMessage = ValidationService.sanitizeText(message);
    if (cleanMessage == null) {
      throw Exception('Message invalide');
    }
    
    int sent = 0;
    for (final phone in validPhones) {
      try {
        // Envoyer SMS...
        sent++;
        
        // Logger
        await FirebaseFirestore.instance.collection('sms_logs').add({
          'phone': phone,
          'message': cleanMessage,
          'sentAt': FieldValue.serverTimestamp(),
          'sentBy': FirebaseAuth.instance.currentUser?.uid,
        });
      } catch (e) {
        debugPrint('Erreur envoi SMS à $phone: $e');
      }
    }
    
    return sent;
  }
}
```

---

## 5. Protection des Secrets

### 5.1 Ne JAMAIS Commiter les Secrets

Vérifier `.gitignore` :

```gitignore
# Secrets
.env
.env.*
!.env.example
environments/.env.*
!environments/.env.*.example

# Firebase
google-services.json
GoogleService-Info.plist
firebase_options.dart

# Cloudinary
cloudinary_config.dart

# Clés API
**/config.dart
**/secrets.dart

# Android
android/key.properties
android/app/upload-keystore.jks
android/app/debug.keystore

# iOS
ios/Runner/GoogleService-Info.plist
ios/firebase_app_id_file.json
```

### 5.2 Utiliser Firebase Remote Config (Production)

Au lieu de `.env` files, utiliser Firebase Remote Config :

```dart
// services/config_service.dart
import 'package:firebase_remote_config/firebase_remote_config.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._();
  ConfigService._();
  
  late final FirebaseRemoteConfig _remoteConfig;
  
  Future<void> initialize() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Valeurs par défaut
    await _remoteConfig.setDefaults({
      'cloudinary_cloud_name': '',
      'cloudinary_upload_preset': '',
      'max_post_length': 10000,
      'max_images_per_post': 10,
      'enable_audio_messages': true,
    });
    
    await _remoteConfig.fetchAndActivate();
  }
  
  String get cloudinaryCloudName => _remoteConfig.getString('cloudinary_cloud_name');
  String get cloudinaryUploadPreset => _remoteConfig.getString('cloudinary_upload_preset');
  int get maxPostLength => _remoteConfig.getInt('max_post_length');
  int get maxImagesPerPost => _remoteConfig.getInt('max_images_per_post');
  bool get enableAudioMessages => _remoteConfig.getBool('enable_audio_messages');
}
```

### 5.3 Secrets Manager (pour production)

Utiliser Google Secret Manager via Cloud Functions :

```typescript
// functions/src/index.ts
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

const client = new SecretManagerServiceClient();

export const getCloudinaryCredentials = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Auth requise');
  }
  
  const [version] = await client.accessSecretVersion({
    name: 'projects/YOUR_PROJECT_ID/secrets/cloudinary-api-key/versions/latest',
  });
  
  const apiKey = version.payload?.data?.toString();
  
  return { apiKey };
});
```

---

## 6. Sécurité Réseau

### 6.1 Certificate Pinning (SSL Pinning)

```dart
// lib/services/http_service.dart
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';

class SecureHttpClient {
  static IOClient? _client;
  
  static IOClient getClient() {
    if (_client != null) return _client!;
    
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Vérifier le certificat Cloudinary
        if (host == 'res.cloudinary.com') {
          // Ajouter votre logique de pinning ici
          // Comparer cert.sha256 avec le hash attendu
          return true; // Temporaire
        }
        return false;
      };
    
    _client = IOClient(httpClient);
    return _client!;
  }
}
```

### 6.2 Network Security Config (Android)

`android/app/src/main/res/xml/network_security_config.xml` :

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Base configuration pour production -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    
    <!-- Domaines autorisés -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">firebaseio.com</domain>
        <domain includeSubdomains="true">cloudinary.com</domain>
        <domain includeSubdomains="true">googleapis.com</domain>
    </domain-config>
    
    <!-- Dev seulement (à retirer en prod) -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

Dans `AndroidManifest.xml` :

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

---

## 7. Sécurité du Code

### 7.1 Obfuscation (Android & iOS)

**Android** - `android/app/build.gradle.kts` :

```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        
        // Obfuscation
        signingConfig = signingConfigs.getByName("release")
    }
}
```

**Créer** `android/app/proguard-rules.pro` :

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

**iOS** - Dans Xcode, Target → Build Settings :
- `Strip Debug Symbols During Copy` : YES
- `Strip Linked Product` : YES (Release)
- `Make Strings Read-Only` : YES

### 7.2 Remove Debug Info

**Flutter** - `flutter build` avec :

```bash
# Android
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# iOS
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
```

### 7.3 Jailbreak / Root Detection

```dart
// lib/services/security_service.dart
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:safe_device/safe_device.dart';

class SecurityService {
  static Future<bool> isDeviceSecure() async {
    try {
      // Vérifier jailbreak (iOS) / root (Android)
      final isJailbroken = await FlutterJailbreakDetection.jailbroken;
      if (isJailbroken) {
        return false;
      }
      
      // Vérifier émulateur
      final isRealDevice = await SafeDevice.isRealDevice;
      if (!isRealDevice) {
        // En production, bloquer émulateurs
        return false;
      }
      
      // Vérifier mode développeur (Android)
      final isDevelopmentMode = await SafeDevice.isDevelopmentModeEnable;
      if (isDevelopmentMode) {
        return false;
      }
      
      return true;
    } catch (e) {
      // En cas d'erreur, autoriser (éviter faux positifs)
      return true;
    }
  }
  
  static Future<void> checkDeviceSecurity(BuildContext context) async {
    final isSecure = await isDeviceSecure();
    
    if (!isSecure) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Appareil Non Sécurisé'),
          content: const Text(
            'Cette application ne peut pas fonctionner sur un appareil jailbreaké/rooté ou un émulateur.',
          ),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: const Text('Quitter'),
            ),
          ],
        ),
      );
    }
  }
}
```

**Appeler au démarrage** :

```dart
// main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Vérifier sécurité appareil
  if (!await SecurityService.isDeviceSecure()) {
    runApp(const UnsecureDeviceApp());
    return;
  }
  
  // ...reste du code
}
```

---

## 8. Rate Limiting & Protection DDoS

### 8.1 Firebase App Check

Activer Firebase App Check pour protéger vos backends :

```dart
// main.dart
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // Activer App Check
  await FirebaseAppCheck.instance.activate(
    webRecaptchaSiteKey: 'YOUR_RECAPTCHA_KEY',
    androidProvider: AndroidProvider.playIntegrity, // Pour production
    // androidProvider: AndroidProvider.debug, // Pour dev
    appleProvider: AppleProvider.deviceCheck,
  );
  
  runApp(const MyApp());
}
```

**Dans Firebase Console** :
1. Project Settings → App Check
2. Register apps
3. Set enforcement (warn ou enforce)

### 8.2 Rate Limiting avec Cloud Functions

```typescript
// functions/src/index.ts
import * as admin from 'firebase-admin';

const RATE_LIMIT = 10; // Max 10 requêtes
const RATE_WINDOW = 60000; // Par minute

const rateLimitMap = new Map<string, number[]>();

function checkRateLimit(uid: string): boolean {
  const now = Date.now();
  const timestamps = rateLimitMap.get(uid) || [];
  
  // Filtrer timestamps dans la fenêtre
  const recentTimestamps = timestamps.filter(t => now - t < RATE_WINDOW);
  
  if (recentTimestamps.length >= RATE_LIMIT) {
    return false; // Rate limit dépassé
  }
  
  recentTimestamps.push(now);
  rateLimitMap.set(uid, recentTimestamps);
  
  return true;
}

export const createPost = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Auth requise');
  }
  
  // Vérifier rate limit
  if (!checkRateLimit(context.auth.uid)) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Trop de requêtes. Réessayez dans 1 minute.'
    );
  }
  
  // Créer le post...
});
```

---

## 9. Logs & Monitoring

### 9.1 Firebase Crashlytics

```dart
// main.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // Crashlytics en production seulement
  if (kReleaseMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  runApp(const MyApp());
}
```

### 9.2 Logging Sécurisé

```dart
// services/logger_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum LogLevel { info, warning, error, security }

class LoggerService {
  static Future<void> log({
    required LogLevel level,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // Ne pas logger en debug
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

**Utilisation** :

```dart
// Lors d'une tentative de connexion échouée
await LoggerService.logSecurityEvent(
  event: 'failed_login',
  details: {
    'email': email,
    'error_code': e.code,
  },
);

// Lors d'un accès non autorisé
await LoggerService.logSecurityEvent(
  event: 'unauthorized_access',
  details: {
    'resource': 'admin_panel',
    'user_role': userRole,
  },
);
```

---

## 10. Checklist de Déploiement

### ✅ Avant le Déploiement

#### Firebase
- [ ] Firestore Security Rules déployées et testées
- [ ] Firebase Storage Rules déployées
- [ ] App Check activé
- [ ] Crashlytics configuré
- [ ] Analytics configuré (optionnel)

#### Code
- [ ] Tous les secrets retirés du code
- [ ] `.env` files dans `.gitignore`
- [ ] `debugShowCheckedModeBanner: false`
- [ ] Logs de debug retirés (`print()`, `debugPrint()`)
- [ ] Validation de toutes les entrées utilisateur
- [ ] Rate limiting implémenté

#### Build
- [ ] Build en mode `--release`
- [ ] Obfuscation activée (`--obfuscate`)
- [ ] ProGuard configuré (Android)
- [ ] Stripping activé (iOS)
- [ ] App signée avec certificat production

#### Tests
- [ ] Tester sur appareil réel (pas émulateur)
- [ ] Tester déconnexion/reconnexion
- [ ] Tester avec réseau lent
- [ ] Tester offline mode
- [ ] Tester permissions (photos, micro, notifications)

#### Sécurité
- [ ] Device root/jailbreak detection
- [ ] Certificate pinning
- [ ] Network Security Config (Android)
- [ ] Email verification obligatoire
- [ ] Mots de passe forts requis
- [ ] 2FA optionnel activé (si applicable)

#### Performance
- [ ] Images optimisées (< 1MB chacune)
- [ ] Lazy loading implémenté
- [ ] Cache configuré
- [ ] Pagination sur listes longues

#### Legal
- [ ] Politique de confidentialité
- [ ] Conditions d'utilisation
- [ ] Mentions RGPD (si Europe)
- [ ] Consentement cookies/tracking

---

## 📚 Ressources Complémentaires

### Documentation Officielle
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

### Packages Recommandés
```yaml
dependencies:
  # Sécurité
  firebase_app_check: ^0.2.1+1
  flutter_jailbreak_detection: ^1.10.0
  safe_device: ^1.1.5
  
  # SSL Pinning
  http_certificate_pinning: ^2.0.0
  
  # Validation
  validators: ^3.0.0
  
  # Monitoring
  firebase_crashlytics: ^3.4.9
  firebase_analytics: ^10.8.0
  
  # Storage sécurisé
  flutter_secure_storage: ^9.0.0
  
  # Biométrie
  local_auth: ^2.1.8
```

---

## 🚨 Incident Response

### En cas de Faille Détectée

1. **Isolation immédiate**
   - Désactiver la fonctionnalité compromise
   - Bloquer les accès suspects via Firestore Rules

2. **Investigation**
   - Analyser les logs Firebase
   - Identifier l'étendue de la faille
   - Lister les données exposées

3. **Correction**
   - Patcher la vulnérabilité
   - Déployer en urgence
   - Forcer update app si critique

4. **Communication**
   - Notifier les utilisateurs affectés
   - Publier post-mortem (interne)
   - Mettre à jour documentation

5. **Prévention**
   - Ajouter tests pour cette faille
   - Améliorer monitoring
   - Former l'équipe

---

## 📞 Support

Pour toute question de sécurité :
- 🔒 **Email sécurisé** : security@votre-domaine.com
- 📱 **Bug Bounty** : Considérer un programme de récompense
- 🛡️ **Audit de sécurité** : Recommandé tous les 6-12 mois

---

**Dernière mise à jour** : 29 Décembre 2025
**Version** : 1.0

