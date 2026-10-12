import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hermin/services/conversation_service.dart';
import '../ui/components/app_search_field.dart';
import '../ui/components/state_widgets.dart';
import '../ui/layouts/app_page_scaffold.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Non authentifie')));
    }

    return AppPageScaffold(
      title: 'Conversations',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ConversationService.instance.conversationsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppSkeleton(count: 6);
          }
          if (snap.hasError) {
            return const AppErrorState(message: 'Impossible de charger les conversations.');
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Aucune conversation',
              subtitle: 'Appuyez sur + pour commencer',
            );
          }

          return ListView.builder(
            itemCount: docs.length,
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

              return _ConversationTile(
                title: title,
                lastMessage: last,
                lastUpdated: lastUpdated,
                hasUnread: hasUnread,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(conversationId: d.id, title: title)),
                ),
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
      showDragHandle: true,
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
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convRef.id, title: 'Support')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_search),
                title: const Text('Nouveau chat avec un utilisateur'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _UserPickerScreen(currentUserId: uid)));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.title,
    required this.lastMessage,
    required this.lastUpdated,
    required this.hasUnread,
    required this.onTap,
  });

  final String title;
  final String lastMessage;
  final DateTime? lastUpdated;
  final bool hasUnread;
  final VoidCallback onTap;

  String _getTimeAgo() {
    if (lastUpdated == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastUpdated!);
    if (diff.inMinutes < 1) return 'a l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return '${(diff.inDays / 7).floor()}sem';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 10,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: cs.primaryContainer,
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600)),
      subtitle: Text(lastMessage.isEmpty ? 'Aucun message' : lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_getTimeAgo(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          if (hasUnread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _UserPickerScreen extends StatefulWidget {
  const _UserPickerScreen({required this.currentUserId});

  final String currentUserId;

  @override
  State<_UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<_UserPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _searchQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').limit(100).get();
      setState(() {
        _allUsers = snap.docs.where((d) => d.id != widget.currentUserId).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de chargement')));
      setState(() => _loading = false);
    }
  }

  Future<void> _startConversation(QueryDocumentSnapshot<Map<String, dynamic>> userDoc) async {
    final name = (userDoc.data()['displayName'] as String?) ?? (userDoc.data()['username'] as String?) ?? 'Utilisateur';
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final convRef = await ConversationService.instance.getOrCreateConversation([widget.currentUserId, userDoc.id], title: name);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convRef.id, title: name)));
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de creation de conversation')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _allUsers
        : _allUsers.where((d) {
            final data = d.data();
            final name = ((data['displayName'] as String?) ?? (data['username'] as String?) ?? '').toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

    return AppPageScaffold(
      title: 'Nouveau message',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppSearchField(controller: _searchController, hintText: 'Rechercher une personne...'),
          ),
          Expanded(
            child: _loading
                ? const AppSkeleton(count: 6)
                : filtered.isEmpty
                    ? const AppEmptyState(icon: Icons.people_outline, title: 'Aucun utilisateur', subtitle: 'Aucun resultat disponible')
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final data = filtered[i].data();
                          final name = (data['displayName'] as String?) ?? (data['username'] as String?) ?? 'Utilisateur';
                          final photo = data['photoUrl'] as String?;
                          return ListTile(
                            onTap: () => _startConversation(filtered[i]),
                            leading: CircleAvatar(
                              backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                              child: (photo == null || photo.isEmpty) ? Text(name[0].toUpperCase()) : null,
                            ),
                            title: Text(name),
                            trailing: const Icon(Icons.chevron_right),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


