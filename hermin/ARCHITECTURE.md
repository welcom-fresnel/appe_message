# 📦 Architecture du Projet Hermin

## 🗂️ Structure des fichiers

```
lib/
├── main.dart                          # Point d'entrée
├── notification_service.dart          # Service de notifications locales
├── screens/
│   ├── auth_screen.dart
│   ├── feed_screen.dart
│   ├── home_shell.dart
│   ├── announcements_screen.dart
│   └── profile_screen.dart
└── services/                          # ✨ Nouveaux services
    ├── index.dart                     # Export centralisé
    ├── auth_service.dart              # Authentification Firebase
    ├── user_service.dart              # Gestion utilisateurs
    ├── message_service.dart           # Gestion des messages
    ├── firebase_service.dart          # Configuration Firebase Messaging
    └── notification_handler.dart      # Orchestre les notifications
```

## 🎯 Services disponibles

### 1. **AuthService** - Authentification
- Connexion/Inscription
- Déconnexion
- Gestion du profil
- Vérification email

```dart
AuthService.instance.authStateChanges    // Stream Auth
AuthService.instance.currentUser         // User Firebase
AuthService.instance.isAuthenticated     // bool
```

### 2. **UserService** - Gestion Utilisateurs
- Profils utilisateurs
- Catégories
- Streams temps réel

```dart
UserService.instance.currentUserStream       // Stream<UserModel?>
UserService.instance.currentUserCategoryStream // Stream<String?>
UserService.instance.getUserByUid()          // Future<UserModel?>
```

### 3. **MessageService** - Gestion Messages
- Messages texte et audio
- Streams par catégorie
- Recherche

```dart
MessageService.instance.getMessagesByCategoryStream() // Stream<List<MessageModel>>
MessageService.instance.sendTextMessage()            // Future<String?>
MessageService.instance.sendAudioMessage()           // Future<String?>
```

### 4. **NotificationHandler** - Notifications
Automatiquement initialisé au démarrage
- Messages au premier plan
- Messages en arrière-plan
- Taps sur notifications

### 5. **FirebaseService** - Firebase Messaging
Configuration des permissions et tokens
- Permissions
- FCM Token
- Message streams

## 🔄 Flux de données

```
┌─────────────────────────────────────────────┐
│         Authentification (AuthService)      │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│        Utilisateur connecté (UserService)   │
│     • Récupère catégorie                    │
│     • Crée profil                           │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│      Messages par catégorie (MessageService)│
│     • Stream messages                       │
│     • Envoie message                        │
│     • Edite/Supprime                        │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│   Notifications (NotificationHandler)       │
│     • Display notification                  │
│     • Handle tap                            │
└─────────────────────────────────────────────┘
```

## 📊 Modèles de données

### UserModel
```dart
UserModel(
  uid: String,
  email: String?,
  displayName: String?,
  category: String?,
  photoUrl: String?,
  createdAt: DateTime?,
)
```

### MessageModel
```dart
MessageModel(
  id: String,
  senderId: String,
  senderName: String?,
  senderPhotoUrl: String?,
  text: String?,              // Pour messages texte
  audioUrl: String?,          // Pour messages audio
  type: String,               // 'text' ou 'audio'
  categories: List<String>,
  createdAt: DateTime,
  updatedAt: DateTime?,
)
```

## 🚀 Utilisation rapide

### Dans un Widget
```dart
import 'services/index.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService.instance.currentUserStream,
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox();
        
        final category = userSnapshot.data?.category;
        if (category == null) return const Text('Catégorie requise');

        return StreamBuilder<List<MessageModel>>(
          stream: MessageService.instance
              .getMessagesByCategoryStream(category),
          builder: (context, msgSnapshot) {
            final messages = msgSnapshot.data ?? [];
            return ListView(
              children: messages
                  .map((msg) => MessageTile(message: msg))
                  .toList(),
            );
          },
        );
      },
    );
  }
}
```

### Envoyer un message
```dart
void _sendMessage() async {
  final user = UserService.instance.currentUser;
  final category = await UserService.instance.getCurrentUserCategory();
  
  if (user != null && category != null) {
    await MessageService.instance.sendTextMessage(
      senderId: user.uid,
      text: _textController.text,
      categories: [category],
      senderName: user.displayName,
    );
  }
}
```

## ✨ Avantages de cette architecture

✅ **Séparation des responsabilités** - Chaque service a une tâche unique
✅ **Réutilisabilité** - Services accessibles partout
✅ **Testabilité** - Facile à tester et mocker
✅ **Maintenabilité** - Code organisé et documenté
✅ **Scalabilité** - Facile d'ajouter de nouveaux services
✅ **Performance** - Streams pour données temps réel
✅ **Erreurs gérées** - Try-catch et logs partout

## 📝 Prochaines étapes suggérées

1. **Implémentation Riverpod** - Pour gérer l'état globalement
2. **Screens refactorisées** - Utiliser les services dans les widgets
3. **Tests unitaires** - Tester chaque service
4. **Navigation améliorée** - go_router avec guards
5. **Upload fichiers** - Intégrer Firebase Storage
