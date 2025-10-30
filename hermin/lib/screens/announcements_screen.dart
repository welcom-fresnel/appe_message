import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _bellPlayer = AudioPlayer();
  bool _bellLoaded = false;
  bool _initialSnapshotHandled = false;
  final Set<String> _seenIds = <String>{};
  String? _subscribedCategory;

  @override
  void initState() {
    super.initState();
    _preloadBell();
  }

  Future<void> _preloadBell() async {
    try {
      await _bellPlayer.setAsset('assets/bell.mp3');
      _bellLoaded = true;
    } catch (_) {
      _bellLoaded = false; // asset manquant: on ignore
    }
  }

  Future<void> _playBell() async {
    if (!_bellLoaded) return;
    try {
      await _bellPlayer.seek(Duration.zero);
      await _bellPlayer.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _bellPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annonces'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: uid != null
            ? FirebaseFirestore.instance.collection('users').doc(uid).get()
            : Future.value(null),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = userSnap.data?.data();
          final category = userData != null ? userData['category'] as String? : null;
          if (category == null) {
            return const Center(child: Text('Veuillez définir votre catégorie.'));
          }
          // Subscribe once to FCM topic for background notifications
          if (_subscribedCategory != category) {
            _subscribedCategory = category;
            FirebaseMessaging.instance.subscribeToTopic('category_' + category);
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .where('categories', arrayContains: category)
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

              // Détection des nouvelles annonces après le premier chargement
              if (!_initialSnapshotHandled) {
                _seenIds.addAll(docs.map((d) => d.id));
                _initialSnapshotHandled = true;
              } else {
                final incomingIds = docs.map((d) => d.id).toSet();
                final newIds = incomingIds.difference(_seenIds);
                if (newIds.isNotEmpty) {
                  _seenIds.addAll(newIds);
                  _playBell();
                }
              }

              if (docs.isEmpty) {
                return const Center(child: Text('Aucune annonce'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final type = data['type'] as String?;
                  final ts = data['createdAt'];
                  final authorName = data['authorName'] as String? ?? 'Administration';
                  final authorPhotoUrl = data['authorPhotoUrl'] as String?;
                  if (type == 'text') {
                    final text = data['text'] as String? ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (authorPhotoUrl != null && authorPhotoUrl.isNotEmpty)
                            ? NetworkImage(authorPhotoUrl)
                            : null,
                        child: (authorPhotoUrl == null || authorPhotoUrl.isEmpty)
                            ? const Icon(Icons.campaign)
                            : null,
                      ),
                      title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(ts is Timestamp ? ts.toDate().toString() : ''),
                      isThreeLine: text.isNotEmpty,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(authorName),
                            content: Text(text),
                          ),
                        );
                      },
                    );
                  }
                  final url = data['audioUrl'] as String? ?? '';
                  return AudioAnnouncementTile(
                    url: url,
                    authorName: authorName,
                    authorPhotoUrl: authorPhotoUrl,
                    timestamp: ts is Timestamp ? ts.toDate() : null,
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

class AudioAnnouncementTile extends StatefulWidget {
  final String url;
  final String authorName;
  final String? authorPhotoUrl;
  final DateTime? timestamp;
  const AudioAnnouncementTile({super.key, required this.url, required this.authorName, this.authorPhotoUrl, this.timestamp});

  @override
  State<AudioAnnouncementTile> createState() => _AudioAnnouncementTileState();
}

class _AudioAnnouncementTileState extends State<AudioAnnouncementTile> {
  final _player = AudioPlayer();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _player.setUrl(widget.url);
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de charger l\'audio');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.timestamp != null ? widget.timestamp!.toString() : '';
    if (_loading) {
      return ListTile(
        leading: CircleAvatar(
          child: const Icon(Icons.campaign),
          backgroundImage: (widget.authorPhotoUrl != null && widget.authorPhotoUrl!.isNotEmpty)
              ? NetworkImage(widget.authorPhotoUrl!)
              : null,
        ),
        title: Text(widget.authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: (widget.authorPhotoUrl != null && widget.authorPhotoUrl!.isNotEmpty)
              ? NetworkImage(widget.authorPhotoUrl!)
              : null,
          child: (widget.authorPhotoUrl == null || widget.authorPhotoUrl!.isEmpty)
              ? const Icon(Icons.campaign)
              : null,
        ),
        title: Text(widget.authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.redAccent),
          onPressed: _init,
          tooltip: 'Réessayer',
        ),
      );
    }
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (widget.authorPhotoUrl != null && widget.authorPhotoUrl!.isNotEmpty)
                ? NetworkImage(widget.authorPhotoUrl!)
                : null,
            child: (widget.authorPhotoUrl == null || widget.authorPhotoUrl!.isEmpty)
                ? const Icon(Icons.campaign)
                : null,
          ),
          title: Text(widget.authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: IconButton(
            icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 28, color: Colors.blueAccent),
            onPressed: () => playing ? _player.pause() : _player.play(),
          ),
        );
      },
    );
  }
}
