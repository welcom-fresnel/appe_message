# 🚀 Guide d'utilisation des Services

## Services disponibles

### 1. **UserService** - Gestion des utilisateurs
```dart
import 'services/index.dart';

// Récupérer l'utilisateur actuel
final user = UserService.instance.currentUser;

// Stream de l'utilisateur actuel
UserService.instance.currentUserStream.listen((user) {
  print('Utilisateur: $user');
});

// Récupérer la catégorie de l'utilisateur
final category = await UserService.instance.getCurrentUserCategory();

// Stream de la catégorie
UserService.instance.currentUserCategoryStream.listen((category) {
  print('Catégorie: $category');
});

// Mettre à jour la catégorie
await UserService.instance.updateUserCategory('classe-8B');

// Créer/mettre à jour le profil
await UserService.instance.createOrUpdateProfile(
  displayName: 'Jean Dupont',
  photoUrl: 'https://...',
  category: 'classe-8B',
);

// Récupérer un utilisateur par UID
final user = await UserService.instance.getUserByUid('uid123');

// Déconnexion
await UserService.instance.signOut();
```

### 2. **MessageService** - Gestion des messages
```dart
import 'services/index.dart';

// Stream des messages pour une catégorie
MessageService.instance
    .getMessagesByCategoryStream('classe-8B')
    .listen((messages) {
  print('Messages: $messages');
});

// Récupérer les messages une fois
final messages = await MessageService.instance.getMessagesByCategory(
  'classe-8B',
  limit: 50,
);

// Envoyer un message texte
await MessageService.instance.sendTextMessage(
  senderId: 'uid123',
  text: 'Bonjour tout le monde!',
  categories: ['classe-8B'],
  senderName: 'Jean',
  senderPhotoUrl: 'https://...',
);

// Envoyer un message audio
await MessageService.instance.sendAudioMessage(
  senderId: 'uid123',
  audioUrl: 'https://storage.com/audio.m4a',
  categories: ['classe-8B'],
  senderName: 'Jean',
);

// Mettre à jour un message texte
await MessageService.instance.updateTextMessage(
  'messageId123',
  'Nouveau texte',
);

// Supprimer un message
await MessageService.instance.deleteMessage('messageId123');

// Récupérer un message par ID
final message = await MessageService.instance.getMessageById('messageId123');

// Rechercher des messages
final results = await MessageService.instance.searchMessages(
  'bonjour',
  category: 'classe-8B',
);
```

### 3. **NotificationHandler** - Gestion des notifications

Automatiquement initialisé dans `main()`. Gère:
- ✅ Messages entrants (app au premier plan)
- ✅ Messages en arrière-plan
- ✅ Taps sur notifications
- ✅ Lancement de l'app depuis une notification

Aucune configuration nécessaire!

### 4. **FirebaseService** - Configuration Firebase

Automatiquement initialisé dans `main()`. Fournit:
- ✅ Gestion des permissions
- ✅ Token FCM pour notifications ciblées
- ✅ Streams pour écouter les messages

```dart
import 'services/index.dart';

// Récupérer le token FCM
final token = await FirebaseService.instance.getFCMToken();
print('Token: $token');

// Écouter les messages entrants
FirebaseService.instance.onMessageStream.listen((message) {
  print('Message: $message');
});
```

## 📋 Exemple complet: Écran de feed avec messages

```dart
import 'package:flutter/material.dart';
import '../services/index.dart';

class MessageFeedScreen extends StatefulWidget {
  const MessageFeedScreen({super.key});

  @override
  State<MessageFeedScreen> createState() => _MessageFeedScreenState();
}

class _MessageFeedScreenState extends State<MessageFeedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<String?>(
        stream: UserService.instance.currentUserCategoryStream,
        builder: (context, categorySnapshot) {
          // Attendre la catégorie
          if (!categorySnapshot.hasData || categorySnapshot.data == null) {
            return const Center(child: Text('Catégorie non définie'));
          }

          final category = categorySnapshot.data!;

          // Ensuite récupérer les messages de cette catégorie
          return StreamBuilder<List<MessageModel>>(
            stream: MessageService.instance.getMessagesByCategoryStream(category),
            builder: (context, messageSnapshot) {
              if (messageSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (messageSnapshot.hasError) {
                return Center(child: Text('Erreur: ${messageSnapshot.error}'));
              }

              final messages = messageSnapshot.data ?? [];

              if (messages.isEmpty) {
                return const Center(child: Text('Aucun message'));
              }

              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Card(
                    child: ListTile(
                      title: Text(msg.text ?? 'Message audio'),
                      subtitle: Text(msg.senderName ?? 'Anonyme'),
                      leading: msg.type == 'audio'
                          ? const Icon(Icons.mic)
                          : const Icon(Icons.message),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

## 🔄 Workflows courants

### Envoyer un message avec la catégorie utilisateur
```dart
final currentUser = UserService.instance.currentUser;
final category = await UserService.instance.getCurrentUserCategory();

if (currentUser != null && category != null) {
  await MessageService.instance.sendTextMessage(
    senderId: currentUser.uid,
    text: 'Mon message',
    categories: [category],
    senderName: currentUser.displayName,
  );
}
```

### Afficher les messages avec le stream utilisateur
```dart
StreamBuilder<UserModel?>(
  stream: UserService.instance.currentUserStream,
  builder: (context, userSnapshot) {
    if (!userSnapshot.hasData) return const SizedBox();
    
    final category = userSnapshot.data?.category;
    if (category == null) return const Text('Pas de catégorie');

    return StreamBuilder<List<MessageModel>>(
      stream: MessageService.instance.getMessagesByCategoryStream(category),
      builder: (context, messageSnapshot) {
        final messages = messageSnapshot.data ?? [];
        return ListView(children: [...]);
      },
    );
  },
)
```

## 📊 Structure des modèles

### UserModel
```dart
UserModel(
  uid: 'user123',
  email: 'user@example.com',
  displayName: 'Jean Dupont',
  category: 'classe-8B',
  photoUrl: 'https://...',
  createdAt: DateTime.now(),
)
```

### MessageModel
```dart
MessageModel(
  id: 'msg123',
  senderId: 'user123',
  senderName: 'Jean',
  senderPhotoUrl: 'https://...',
  text: 'Bonjour!', // pour les messages texte
  audioUrl: 'https://...', // pour les messages audio
  type: 'text', // ou 'audio'
  categories: ['classe-8B'],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
)
```

## ⚠️ Points importants

1. **Toujours vérifier** que l'utilisateur est connecté avant d'utiliser les services
2. **Utiliser les streams** pour les données temps réel (meilleure performance)
3. **Utiliser les Future** pour les actions ponctuelles
4. **Les erreurs** sont automatiquement loggées et relancées avec `rethrow`
5. **Les modèles** ont des factories `fromFirestore()` pour faciliter la conversion
