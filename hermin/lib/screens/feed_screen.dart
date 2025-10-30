import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:just_audio/just_audio.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<File> _selectedImages = [];
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;
  String _query = '';

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles.map((x) => File(x.path)).toList();
      });
    }
  }

  Future<void> _addPost() async {
    if (_postController.text.isEmpty && _selectedImages.isEmpty) return;
    setState(() => _isPosting = true);
    final List<String> uploadedUrls = [];
    for (final f in _selectedImages) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/dfw0pwwdr/image/upload'),
        );
        request.files.add(await http.MultipartFile.fromPath('file', f.path));
        request.fields['upload_preset'] = 'hermine_unsigned_audio';
        final response = await request.send();
        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final jsonResp = jsonDecode(respStr);
          final secureUrl = (jsonResp['secure_url'] as String?) ?? '';
          if (secureUrl.isNotEmpty) {
            uploadedUrls.add(
              secureUrl.replaceFirst('/upload/', '/upload/f_jpg/'),
            );
          }
        }
      } catch (_) {
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('posts').add({
      'userId': user?.uid,
      'authorName': user?.displayName,
      'authorPhotoUrl': user?.photoURL,
      'text': _postController.text,
      'mediaUrls': uploadedUrls,
      'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'comments': [],
      'commentsCount': 0,
    });
    setState(() {
      _selectedImages = [];
      _postController.clear();
      _isPosting = false;
    });
    if (mounted) Navigator.of(context).pop();
  }

  void _showAddPostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _postController,
                  decoration: const InputDecoration(labelText: 'Écrire quelque chose...'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                if (_selectedImages.isNotEmpty)
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImages[i],
                          height: 140,
                          width: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _pickImages,
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isPosting ? null : _addPost,
                      child: _isPosting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Publier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Image.asset("assets/logo.png"),
        title: const Text('Hermine'),
        elevation: 20,
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            onPressed: () {
              //implementation de la notification
            },
            icon: const Icon(Icons.notification_add_outlined, color: Colors.blueAccent,),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Rechercher...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: \x1b[${snapshot.error}'));
                }
                var docs = snapshot.data?.docs ?? [];
                // Filtre local
                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final m = d.data();
                    final t = (m['text'] as String?)?.toLowerCase() ?? '';
                    final a = (m['authorName'] as String?)?.toLowerCase() ?? '';
                    return t.contains(_query) || a.contains(_query);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return const Center(child: Text('Aucune publication'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final text = data['text'] as String? ?? '';
                    // Support multiple images like bleumind, fallback to legacy keys
                    List<String> mediaUrls =
                        (data['mediaUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
                    // if only legacy 'mediaUrl' exists, include it
                    if (mediaUrls.isEmpty && data['mediaUrl'] is String && (data['mediaUrl'] as String).isNotEmpty) {
                      mediaUrls = [data['mediaUrl'] as String];
                    }
                    final String? imageUrl = mediaUrls.isNotEmpty
                        ? mediaUrls.first
                        : data['imageUrl'] as String?;
                    final ts = data['createdAt'];
                    final created = ts is Timestamp ? ts.toDate() : null;
                    final isNew = created != null && DateTime.now().difference(created) < const Duration(hours: 24);
                    final postId = docs[index].id;
                    final likes = List<String>.from(data['likes'] ?? []);
                    final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
                    final commentsCount = (data['commentsCount'] as int?) ?? comments.length;
                    final authorName = data['authorName'] as String? ?? 'Utilisateur';
                    final authorPhotoUrl = data['authorPhotoUrl'] as String?;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isLiked = currentUser != null && likes.contains(currentUser.uid);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundImage: authorPhotoUrl != null && authorPhotoUrl.isNotEmpty
                                    ? NetworkImage(authorPhotoUrl)
                                    : null,
                                child: (authorPhotoUrl == null || authorPhotoUrl.isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(created?.toString() ?? ''),
                              trailing: isNew ? const Chip(label: Text('Nouveau')) : null,
                            ),
                            if (mediaUrls.isNotEmpty)
                              _PostMediaCarousel(urls: mediaUrls),
                            if (mediaUrls.isEmpty && imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 4 / 5,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        height: 260,
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) => const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Impossible d\'afficher l\'image'),
                                    ),
                                  ),
                                ),
                              ),
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(text, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 6),
                            ],
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : null),
                                  onPressed: currentUser == null ? null : () async {
                                    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
                                    if (isLiked) {
                                      await postRef.update({
                                        'likes': FieldValue.arrayRemove([currentUser.uid]),
                                      });
                                    } else {
                                      await postRef.update({
                                        'likes': FieldValue.arrayUnion([currentUser.uid]),
                                      });
                                    }
                                  },
                                ),
                                Text('${likes.length}'),
                                const SizedBox(width: 16),
                                const Icon(Icons.comment),
                                Text('$commentsCount'),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.add_comment),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (context) {
                                        final commentController = TextEditingController();
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: commentController,
                                                  decoration: const InputDecoration(labelText: 'Ajouter un commentaire'),
                                                ),
                                                const SizedBox(height: 8),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    final text = commentController.text.trim();
                                                    if (text.isNotEmpty && currentUser != null) {
                                                      final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
                                                      await postRef.update({
                                                        'comments': FieldValue.arrayUnion([
                                                          {
                                                            'userId': currentUser.uid,
                                                            'text': text,
                                                            'createdAt': FieldValue.serverTimestamp(),
                                                          }
                                                        ]),
                                                        'commentsCount': FieldValue.increment(1),
                                                      });
                                                      Navigator.of(context).pop();
                                                    }
                                                  },
                                                  child: const Text('Commenter'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            if (comments.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: comments.take(3).map((c) {
                                  final commentText = c['text'] ?? '';
                                  final commentUser = c['userId'] ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text('$commentUser : $commentText', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPostDialog,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final List<String> urls;
  const _PostMediaCarousel({super.key, required this.urls});

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: widget.urls.length,
              itemBuilder: (context, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stack) => const Center(child: Text("Impossible d'afficher l'image")),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.urls.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? Colors.blueAccent : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class AudioPlayerTile extends StatefulWidget {
  final String url;
  const AudioPlayerTile({super.key, required this.url});

  @override
  State<AudioPlayerTile> createState() => _AudioPlayerTileState();
}

class _AudioPlayerTileState extends State<AudioPlayerTile> {
  final _player = AudioPlayer();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.url);
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
    if (_loading) {
      return const ListTile(
        leading: Icon(Icons.mic),
        title: Text('Chargement du vocal...'),
      );
    }
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return ListTile(
          leading: const Icon(Icons.mic, color: Colors.blueAccent,),
          title: Text(playing ? 'Lecture en cours' : 'Vocal'),
          trailing: IconButton(
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: () => playing ? _player.pause() : _player.play(),
          ),
        );
      },
    );
  }
}
