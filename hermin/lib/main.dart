import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/home_shell.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.instance.init();
  await FirebaseMessaging.instance.requestPermission();
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n != null) {
      NotificationService.instance.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: n.title ?? 'Nouvelle annonce',
        body: n.body ?? '',
      );
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B61F6)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomeShell();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _category;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _category = doc.data() != null ? (doc.data()!['category'] as String?) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _category == null
          ? const Center(child: Text('Catégorie non définie.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('categories', arrayContains: _category)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun message'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final type = data['type'] as String?;
                    if (type == 'text') {
                      final text = data['text'] as String? ?? '';
                      final ts = data['createdAt'];
                      return ListTile(
                        leading: const Icon(Icons.message),
                        title: Text(text),
                        subtitle: Text(ts is Timestamp ? ts.toDate().toString() : ''),
                      );
                    }
                    final url = data['audioUrl'] as String? ?? '';
                    return AudioPlayerTile(url: url);
                  },
                );
              },
            ),
    );
  }
}

