# ⚡ QUICK START - Utilisation rapide des services

## 🎯 Les 3 services principaux

### 1️⃣ AuthService - Authentification
```dart
import 'services/index.dart';

// Écouter les changements d'authentification
AuthService.instance.authStateChanges.listen((user) {
  if (user != null) {
    print('Utilisateur connecté: ${user.email}');
  } else {
    print('Utilisateur déconnecté');
  }
});

// Connexion
await AuthService.instance.signInWithEmail(
  email: 'user@example.com',
  password: 'password123',
);

// Déconnexion
await AuthService.instance.signOut();
```

### 2️⃣ UserService - Profil utilisateur
```dart
import 'services/index.dart';

// Récupérer l'utilisateur actuel EN TEMPS RÉEL
UserService.instance.currentUserStream.listen((user) {
  print('Utilisateur: ${user?.displayName}');
  print('Catégorie: ${user?.category}');
});

// Récupérer la catégorie
final category = await UserService.instance.getCurrentUserCategory();

// Mettre à jour le profil
await UserService.instance.createOrUpdateProfile(
  displayName: 'Jean Dupont',
  category: 'classe-8B',
);

// Mettre à jour la catégorie
await UserService.instance.updateUserCategory('classe-8B');
```

### 3️⃣ MessageService - Messages
```dart
import 'services/index.dart';

// Récupérer les messages EN TEMPS RÉEL
MessageService.instance
    .getMessagesByCategoryStream('classe-8B')
    .listen((messages) {
      print('${messages.length} messages');
      for (final msg in messages) {
        print('${msg.senderName}: ${msg.text}');
      }
    });

// Envoyer un message texte
await MessageService.instance.sendTextMessage(
  senderId: 'uid123',
  text: 'Bonjour tout le monde!',
  categories: ['classe-8B'],
  senderName: 'Jean',
);

// Envoyer un message audio
await MessageService.instance.sendAudioMessage(
  senderId: 'uid123',
  audioUrl: 'https://storage.com/audio.m4a',
  categories: ['classe-8B'],
  senderName: 'Jean',
);

// Rechercher des messages
final results = await MessageService.instance.searchMessages(
  'bonjour',
  category: 'classe-8B',
);
```

---

## 🎨 Pattern dans un Widget

```dart
import 'package:flutter/material.dart';
import 'services/index.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: StreamBuilder<UserModel?>(
        // 1️⃣ Récupérer l'utilisateur
        stream: UserService.instance.currentUserStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: Text('Connectez-vous'));
          }

          final user = userSnapshot.data!;
          final category = user.category;

          if (category == null) {
            return const Center(child: Text('Catégorie requise'));
          }

          // 2️⃣ Récupérer les messages de cette catégorie
          return StreamBuilder<List<MessageModel>>(
            stream: MessageService.instance
                .getMessagesByCategoryStream(category),
            builder: (context, msgSnapshot) {
              if (msgSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = msgSnapshot.data ?? [];

              if (messages.isEmpty) {
                return const Center(child: Text('Aucun message'));
              }

              // 3️⃣ Afficher les messages
              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return ListTile(
                    leading: msg.type == 'audio'
                        ? const Icon(Icons.mic)
                        : const Icon(Icons.message),
                    title: Text(msg.text ?? 'Message audio'),
                    subtitle: Text(msg.senderName ?? 'Anonyme'),
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

---

## 🔄 Flux complet

```
1. DÉMARRAGE
   └─> main() initialise Firebase et services

2. AUTHENTIFICATION
   └─> AuthService.instance.authStateChanges
       └─> Utilisateur connecté ou non?

3. PROFIL
   └─> UserService.instance.currentUserStream
       └─> Récupère catégorie utilisateur

4. MESSAGES
   └─> MessageService.instance.getMessagesByCategoryStream()
       └─> Affiche les messages

5. NOTIFICATION
   └─> NotificationHandler reçoit message
       └─> NotificationService affiche local
           └─> Utilisateur tap → action
```

---

## ⚠️ Points importants

### ✅ À FAIRE
```dart
// Utiliser les streams pour données temps réel
UserService.instance.currentUserStream.listen(...);

// Utiliser les futures pour actions ponctuelles
await MessageService.instance.sendTextMessage(...);

// Toujours vérifier null/empty
if (category != null && category.isNotEmpty) { ... }

// Ajouter error handling
try {
  await UserService.instance.updateUserCategory(...);
} catch (e) {
  print('Erreur: $e');
}
```

### ❌ À ÉVITER
```dart
// Ne JAMAIS utiliser Firestore direct
FirebaseFirestore.instance.collection('users')...

// Ne JAMAIS utiliser FirebaseAuth direct
FirebaseAuth.instance.currentUser

// Ne JAMAIS utiliser setState
setState(() { _data = ...; });

// Ne JAMAIS ignorer les erreurs
await SomeService.instance.someMethod(); // Pas de try-catch!
```

---

## 🧪 Tester les services

```dart
import 'services/index.dart';

void main() {
  // Test UserService
  print('=== Test UserService ===');
  UserService.instance.currentUserStream.listen((user) {
    print('Utilisateur: $user');
  });

  // Test MessageService
  print('=== Test MessageService ===');
  MessageService.instance
      .getMessagesByCategoryStream('test')
      .listen((messages) {
        print('Messages: $messages');
      });
}
```

---

## 📚 Documentation complète

- **Guide complet**: Lire `SERVICES_GUIDE.md`
- **Architecture**: Lire `ARCHITECTURE.md`
- **Exemples**: Lire `REFACTORING_EXAMPLES.md`
- **À faire**: Consulter `TODO.md`

---

## 💡 Tips & Tricks

### Obtenir l'utilisateur une seule fois
```dart
final user = UserService.instance.currentUser;
```

### Obtenir la catégorie rapidement
```dart
final category = await UserService.instance
    .getCurrentUserCategory();
```

### Envoyer message avec données actuelles
```dart
final user = UserService.instance.currentUser;
final category = await UserService.instance
    .getCurrentUserCategory();

if (user != null && category != null) {
  await MessageService.instance.sendTextMessage(
    senderId: user.uid,
    text: text,
    categories: [category],
    senderName: user.displayName,
  );
}
```

### Chercher dans des messages
```dart
final results = await MessageService.instance.searchMessages(
  query,
  category: userCategory,
);
```

---

**Besoin d'aide? Lis la documentation complète!** 📚
