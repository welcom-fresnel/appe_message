import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hermin/services/conversation_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Non authentifié')));

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ConversationService.instance.conversationsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur: \\${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('Aucune conversation'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final participants = List<String>.from(data['participants'] ?? []);
              final title = (data['title'] as String?)?.isNotEmpty == true
                  ? data['title'] as String
                  : participants.where((p) => p != uid).join(', ');
              final last = (data['lastMessage'] as String?) ?? '';
              final lastUpdatedRaw = data['lastUpdated'];
              final lastReadMap = data['lastRead'] as Map<String, dynamic>?;
              final lastReadRaw = (lastReadMap != null && lastReadMap.containsKey(uid)) ? lastReadMap[uid] : null;
              DateTime? lastUpdated;
              DateTime? lastRead;
              if (lastUpdatedRaw is Timestamp) lastUpdated = lastUpdatedRaw.toDate();
              if (lastReadRaw is Timestamp) lastRead = lastReadRaw.toDate();
              final hasUnread = lastUpdated != null && (lastRead == null || lastUpdated.isAfter(lastRead));

              return ListTile(
                title: Text(title),
                subtitle: last.isNotEmpty ? Text(last, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                trailing: hasUnread ? Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: const Text('N', style: TextStyle(color: Colors.white, fontSize: 12))) : null,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: d.id, title: title)));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewConversationSheet(context, uid),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showNewConversationSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Contacter l\'admin'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final convRef = await ConversationService.instance.getOrCreateConversation([uid, 'admin'], title: 'Support');
                  if (!ctx.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convRef.id, title: 'Support')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_search),
                title: const Text('Nouveau chat avec un utilisateur'),
                onTap: () async {
                  Navigator.pop(ctx);
                  _openUserPicker(context, uid);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUserPicker(BuildContext context, String uid) async {
    final snap = await FirebaseFirestore.instance.collection('users').limit(100).get();
    final users = snap.docs.where((d) => d.id != uid).toList();
    if (users.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun utilisateur trouvé')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (ctx, i) {
            final d = users[i];
            final name = (d.data()['displayName'] as String?) ?? (d.data()['username'] as String?) ?? 'Utilisateur';
            return ListTile(
              title: Text(name),
              subtitle: Text(d.id),
              onTap: () async {
                Navigator.pop(ctx);
                final convRef = await ConversationService.instance.getOrCreateConversation([uid, d.id], title: name);
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convRef.id, title: name)));
              },
            );
          },
        ),
      ),
    );
  }
}
