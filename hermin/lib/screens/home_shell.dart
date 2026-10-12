import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/components/app_badged_icon.dart';
import 'feed_screen.dart';
import 'announcements_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _pages = const [
    FeedScreen(),
    ChatListScreen(),
    AnnouncementsScreen(),
    ProfileScreen(),
  ];

  Stream<int> _getUnreadConversationsCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
          int unreadCount = 0;
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final lastReadTimestamps = userDoc.data()?['conversationsLastRead'] as Map<String, dynamic>? ?? {};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lastUpdated = data['lastUpdated'] as Timestamp?;
            if (lastUpdated == null) continue;

            final lastReadTimestamp = lastReadTimestamps[doc.id] as Timestamp?;
            if (lastReadTimestamp == null || lastUpdated.toDate().isAfter(lastReadTimestamp.toDate())) {
              final lastMessageSender = data['lastMessageSenderId'] as String?;
              if (lastMessageSender != null && lastMessageSender != uid) unreadCount++;
            }
          }
          return unreadCount;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: _pages[_index]),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _getUnreadConversationsCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
              NavigationDestination(
                icon: AppBadgedIcon(icon: Icons.group_outlined, count: unreadCount),
                selectedIcon: AppBadgedIcon(icon: Icons.group, count: unreadCount),
                label: 'Messages',
              ),
              const NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Annonces'),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
            ],
          );
        },
      ),
    );
  }
}

