# 📋 Exemples de refactorisation des Screens

## Avant (ancien code)

```dart
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _category;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      _category = doc.data() != null 
          ? (doc.data()!['category'] as String?) 
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('categories', arrayContains: _category)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // ...
      },
    );
  }
}
```

**Problèmes:**
❌ Code dupliqué partout
❌ Logique métier mélangée avec UI
❌ Pas de réutilisabilité
❌ Difficile à tester

---

## Après (nouveau code avec services)

```dart
import 'package:flutter/material.dart';
import '../services/index.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: StreamBuilder<UserModel?>(
        stream: UserService.instance.currentUserStream,
        builder: (context, userSnapshot) {
          // 1️⃣ Attendre l'utilisateur
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || userSnapshot.data?.category == null) {
            return const Center(child: Text('Catégorie non définie'));
          }

          final category = userSnapshot.data!.category!;

          // 2️⃣ Utiliser la catégorie pour récupérer les messages
          return StreamBuilder<List<MessageModel>>(
            stream: MessageService.instance
                .getMessagesByCategoryStream(category),
            builder: (context, msgSnapshot) {
              if (msgSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (msgSnapshot.hasError) {
                return Center(
                  child: Text('Erreur: ${msgSnapshot.error}'),
                );
              }

              final messages = msgSnapshot.data ?? [];

              if (messages.isEmpty) {
                return const Center(child: Text('Aucun message'));
              }

              // 3️⃣ Afficher les messages
              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return MessageTile(message: messages[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Widget réutilisable pour afficher un message
class MessageTile extends StatelessWidget {
  final MessageModel message;

  const MessageTile({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: message.type == 'audio'
            ? const Icon(Icons.mic)
            : const Icon(Icons.message),
        title: Text(message.text ?? 'Message audio'),
        subtitle: Text(message.senderName ?? 'Anonyme'),
        trailing: Text(
          message.createdAt.toString(),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
```

**Avantages:**
✅ Code super propre
✅ Logique séparée dans les services
✅ Facile à tester
✅ Réutilisable

---

## Exemple 2: Screen de profil

```dart
import 'package:flutter/material.dart';
import '../services/index.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    try {
      await UserService.instance.createOrUpdateProfile(
        displayName: _nameController.text,
        category: _categoryController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: StreamBuilder<UserModel?>(
        stream: UserService.instance.currentUserStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          
          // Initialiser les contrôleurs avec les données actuelles
          if (user != null && _nameController.text.isEmpty) {
            _nameController.text = user.displayName ?? '';
            _categoryController.text = user.category ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Enregistrer'),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }
}
```

---

## Exemple 3: Screen d'annonces avec recherche

```dart
import 'package:flutter/material.dart';
import '../services/index.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Annonces')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<UserModel?>(
              stream: UserService.instance.currentUserStream,
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: Text('Connectez-vous'));
                }

                final category = userSnapshot.data?.category;
                if (category == null) {
                  return const Center(child: Text('Catégorie requise'));
                }

                return _buildMessagesList(category);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(String category) {
    // Si recherche active, utiliser searchMessages
    if (_searchQuery.isNotEmpty) {
      return FutureBuilder<List<MessageModel>>(
        future: MessageService.instance
            .searchMessages(_searchQuery, category: category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Center(child: Text('Aucun résultat'));
          }

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) =>
                MessageTile(message: messages[index]),
          );
        },
      );
    }

    // Sinon utiliser le stream
    return StreamBuilder<List<MessageModel>>(
      stream: MessageService.instance
          .getMessagesByCategoryStream(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return const Center(child: Text('Aucun message'));
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) =>
              MessageTile(message: messages[index]),
        );
      },
    );
  }
}
```

---

## ✅ Checklist de refactorisation

- [ ] Utiliser `UserService` pour l'utilisateur connecté
- [ ] Utiliser `MessageService` pour les messages
- [ ] Remplacer tous les `FirebaseAuth.instance` par `AuthService.instance`
- [ ] Remplacer tous les `FirebaseFirestore.instance` par les services
- [ ] Supprimer la logique Firestore des Widgets
- [ ] Créer des widgets réutilisables (MessageTile, UserCard, etc.)
- [ ] Utiliser les streams au lieu des setState
- [ ] Ajouter du error handling partout
- [ ] Tester chaque service individuellement
