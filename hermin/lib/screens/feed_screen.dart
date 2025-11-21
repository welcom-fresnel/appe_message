import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../services/index.dart';

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
    
    try {
      // Upload les images vers Cloudinary
      final uploadedUrls = await CloudinaryService.instance
          .uploadMultipleImages(_selectedImages);
      
      if (uploadedUrls.isEmpty && _postController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: Impossible d\'uploader les images')),
          );
        }
        setState(() => _isPosting = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      
      // Créer les URLs optimisées
      final mediaUrls = uploadedUrls
          .map((r) => r.getOptimizedUrl(width: 800))
          .toList();

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user?.uid,
        'authorName': user?.displayName,
        'authorPhotoUrl': user?.photoURL,
        'text': _postController.text.trim(),
        'mediaUrls': mediaUrls,
        'imageUrl': mediaUrls.isNotEmpty ? mediaUrls.first : null,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'comments': [],
        'commentsCount': 0,
      });

      // Nettoyer et fermer
      setState(() {
        _selectedImages = [];
        _postController.clear();
        _isPosting = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Publication réussie!')),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la publication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
      setState(() => _isPosting = false);
    }
  }

  void _showAddPostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _postController,
                  decoration: const InputDecoration(
                    labelText: 'Écrire quelque chose...',
                  ),
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
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
            icon: const Icon(
              Icons.notification_add_outlined,
              color: Colors.blueAccent,
            ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
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
                        (data['mediaUrls'] as List<dynamic>?)
                            ?.map((e) => e as String)
                            .toList() ??
                        [];
                    // if only legacy 'mediaUrl' exists, include it
                    if (mediaUrls.isEmpty &&
                        data['mediaUrl'] is String &&
                        (data['mediaUrl'] as String).isNotEmpty) {
                      mediaUrls = [data['mediaUrl'] as String];
                    }
                    final String? imageUrl = mediaUrls.isNotEmpty
                        ? mediaUrls.first
                        : data['imageUrl'] as String?;
                    final ts = data['createdAt'];
                    final created = ts is Timestamp ? ts.toDate() : null;
                    final isNew =
                        created != null &&
                        DateTime.now().difference(created) <
                            const Duration(hours: 24);
                    final postId = docs[index].id;
                    final likes = List<String>.from(data['likes'] ?? []);
                    final comments = List<Map<String, dynamic>>.from(
                      data['comments'] ?? [],
                    );
                    final commentsCount =
                        (data['commentsCount'] as int?) ?? comments.length;
                    final authorName =
                        data['authorName'] as String? ?? 'Utilisateur';
                    final authorPhotoUrl = data['authorPhotoUrl'] as String?;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isLiked =
                        currentUser != null && likes.contains(currentUser.uid);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundImage:
                                    authorPhotoUrl != null &&
                                        authorPhotoUrl.isNotEmpty
                                    ? NetworkImage(authorPhotoUrl)
                                    : null,
                                child:
                                    (authorPhotoUrl == null ||
                                        authorPhotoUrl.isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(created?.toString() ?? ''),
                              trailing: isNew
                                  ? const Chip(label: Text('Nouveau'))
                                  : null,
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
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) =>
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Impossible d\'afficher l\'image',
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(text, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 6),
                            ],
                            // Action buttons (Like, Comment, Share, Report)
                            Row(
                              children: [
                                // Like button
                                Expanded(
                                  child: InkWell(
                                    onTap: currentUser == null
                                        ? null
                                        : () async {
                                            final postRef = FirebaseFirestore
                                                .instance
                                                .collection('posts')
                                                .doc(postId);
                                            if (isLiked) {
                                              await postRef.update({
                                                'likes': FieldValue.arrayRemove([
                                                  currentUser.uid,
                                                ]),
                                              });
                                            } else {
                                              await postRef.update({
                                                'likes': FieldValue.arrayUnion([
                                                  currentUser.uid,
                                                ]),
                                              });
                                            }
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: isLiked ? Colors.red : Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            likes.length > 0 ? '${likes.length}' : 'J\'aime',
                                            style: TextStyle(
                                              color: isLiked ? Colors.red : Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Comment button
                                Expanded(
                                  child: InkWell(
                                    onTap: currentUser == null
                                        ? null
                                        : () => _showCommentsSheet(context, postId, currentUser),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.comment_outlined,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            commentsCount > 0 ? '$commentsCount' : 'Commenter',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Report button
                                Expanded(
                                  child: InkWell(
                                    onTap: currentUser == null
                                        ? null
                                        : () => _showReportDialog(context, postId),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.flag_outlined,
                                            color: Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Signaler',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Display first 2 comments with link to see all
                            if (comments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: currentUser == null
                                    ? null
                                    : () => _showCommentsSheet(context, postId, currentUser),
                                child: Text(
                                  'Voir les $commentsCount commentaires',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...comments.take(2).map((c) {
                                final commentText = c['text'] ?? '';
                                final commentUserId = c['userId'] ?? '';
                                return FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(commentUserId)
                                      .get(),
                                  builder: (context, userSnapshot) {
                                    final userName = userSnapshot.data?['displayName'] ?? commentUserId;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '$userName ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                                fontSize: 13,
                                              ),
                                            ),
                                            TextSpan(
                                              text: commentText,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ],
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

  // Affiche tous les commentaires style Facebook
  void _showCommentsSheet(
    BuildContext context,
    String postId,
    User currentUser,
  ) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Commentaires',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Comments List
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final comments = List<Map<String, dynamic>>.from(
                    snapshot.data?['comments'] ?? [],
                  );

                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucun commentaire pour le moment',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final userId = comment['userId'] ?? '';
                      final text = comment['text'] ?? '';
                      final createdAt = comment['createdAt'];
                      final timestamp = createdAt is Timestamp
                          ? createdAt.toDate()
                          : DateTime.now();

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                        builder: (context, userSnapshot) {
                          final userName =
                              userSnapshot.data?['displayName'] ?? 'Utilisateur';
                          final userPhoto = userSnapshot.data?['photoUrl'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: userPhoto.isNotEmpty
                                      ? NetworkImage(userPhoto)
                                      : null,
                                  child: userPhoto.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Comment content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Name and time
                                      Row(
                                        children: [
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getTimeAgo(timestamp),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Comment text
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          text,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete button for own comments
                                if (userId == currentUser.uid)
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: const Text('Supprimer'),
                                        onTap: () async {
                                          await _deleteComment(
                                            postId,
                                            index,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // Input area
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Ajouter un commentaire...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: () async {
                      final text = commentController.text.trim();
                      if (text.isNotEmpty) {
                        final postRef = FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId);

                        await postRef.update({
                          'comments': FieldValue.arrayUnion([
                            {
                              'userId': currentUser.uid,
                              'text': text,
                              'createdAt': FieldValue.serverTimestamp(),
                            },
                          ]),
                          'commentsCount': FieldValue.increment(1),
                        });

                        commentController.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Commentaire publié'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    },
                    child: const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Supprime un commentaire
  Future<void> _deleteComment(String postId, int index) async {
    try {
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId);

      final doc = await postRef.get();
      final comments = List<Map<String, dynamic>>.from(
        doc['comments'] ?? [],
      );

      if (index >= 0 && index < comments.length) {
        comments.removeAt(index);
        await postRef.update({
          'comments': comments,
          'commentsCount': FieldValue.increment(-1),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Commentaire supprimé'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // Dialog pour signaler un contenu
  void _showReportDialog(BuildContext context, String postId) {
    final reasons = [
      'Contenu offensant',
      'Spam',
      'Contenu violent',
      'Partage de données privées',
      'Autre',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler cette publication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pourquoi signalez-vous cette publication?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...reasons.map((reason) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason),
                  onTap: () async {
                    await _submitReport(postId, reason);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Merci de votre signalement. Nous traiterons cette demande rapidement.',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // Enregistre le signalement dans Firestore
  Future<void> _submitReport(String postId, String reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance.collection('reports').add({
        'postId': postId,
        'reportedBy': currentUser.uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('✅ Signalement enregistré: $reason');
    } catch (e) {
      print('❌ Erreur lors du signalement: $e');
    }
  }

  // Fonction pour afficher le temps relatif
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return 'Il y a ${(difference.inDays / 7).floor()}s';
    }
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final List<String> urls;
  const _PostMediaCarousel({required this.urls});

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
                errorBuilder: (context, error, stack) =>
                    const Center(child: Text("Impossible d'afficher l'image")),
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
          leading: const Icon(Icons.mic, color: Colors.blueAccent),
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
