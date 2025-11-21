import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

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
  String? _subscribedTopic;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String _normalizeCategory(String input) {
    final lower = input.toLowerCase();
    return lower
        .replaceAll(RegExp('[àáâäå]'), 'a')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[òóôö]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll('ÿ', 'y')
        .replaceAll('œ', 'oe')
        .replaceAll('æ', 'ae');
  }

  String? _sanitizeTopicName(String input) {
    // Topics must match [A-Za-z0-9-_.~%] and be 1..900 chars, and not start with "/topics/"
    var value = input.trim();
    if (value.startsWith('/topics/')) {
      value = value.substring('/topics/'.length);
    }
    // Replace spaces with underscores, drop invalid characters
    value = value
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r"[^A-Za-z0-9\-_.~%]"), '');
    if (value.isEmpty) return null;
    if (value.length > 900) value = value.substring(0, 900);
    return value;
  }

  // Couleurs du thème
  final Color _primaryColor = const Color(0xFF4F6F52);
  final Color _accentColor = const Color(0xFF86A789);
  final Color _backgroundColor = const Color(0xFFF5EFE6);
  final Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _preloadBell();
  }

  @override
  void dispose() {
    _bellPlayer.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _preloadBell() async {
    try {
      await _bellPlayer.setAsset('assets/bell.mp3');
      setState(() => _bellLoaded = true);
    } catch (e) {
      debugPrint('Erreur lors du chargement du son: $e');
      setState(() => _bellLoaded = false);
    }
  }

  Future<void> _playBell() async {
    if (!_bellLoaded) return;
    try {
      await _bellPlayer.seek(Duration.zero);
      await _bellPlayer.play();
    } catch (e) {
      debugPrint('Erreur lors de la lecture du son: $e');
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Annonces',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Restez informé des dernières actualités',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher des annonces...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.grey[200],
        selectedColor: _primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> data, bool isNew) {
    final date = (data['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
    final type = data['type'] as String?;
    final authorName = data['authorName'] as String? ?? 'Administration';
    final authorPhotoUrl = data['authorPhotoUrl'] as String?;
    final text = data['text'] as String? ?? '';
    final audioUrl = data['audioUrl'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          if (type == 'text') {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(authorName),
                content: Text(text),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: _cardColor,
            border: isNew
                ? Border.all(color: _accentColor.withOpacity(0.5), width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      type == 'audio' ? Icons.volume_up : Icons.announcement,
                      color: _primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        'Nouveau',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (type == 'text' && text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (type == 'audio' && audioUrl != null) ...[
                const SizedBox(height: 12),
                AudioAnnouncementTile(
                  url: audioUrl,
                  authorName: authorName,
                  authorPhotoUrl: authorPhotoUrl,
                  timestamp: date,
                ),
              ],
              const SizedBox(height: 8),
              if (data['categories'] is List &&
                  (data['categories'] as List).isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: (data['categories'] as List)
                      .map<Widget>(
                        (category) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category.toString(),
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            height: 180,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.announcement_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune annonce disponible',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revenez plus tard pour voir les nouvelles annonces',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: uid != null
            ? FirebaseFirestore.instance.collection('users').doc(uid).get()
            : null,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer();
          }

          final userData = userSnap.data?.data();
          final category = userData != null
              ? userData['category'] as String?
              : null;

          if (category == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.orange[400],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Catégorie non définie',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Veuvez-vous définir votre catégorie dans les paramètres de votre profil pour voir les annonces correspondantes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Naviguer vers l'écran de profil
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Aller au profil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Subscribe once to FCM topic for background notifications (only valid topic names)
          final normalizedCategory = _normalizeCategory(category);
          final candidateTopic = _sanitizeTopicName('category_${normalizedCategory}');
          if (candidateTopic != null && _subscribedTopic != candidateTopic) {
            _subscribedTopic = candidateTopic;
            FirebaseMessaging.instance.subscribeToTopic(candidateTopic);
          }

          return Column(
            children: [
              _buildHeader(),

              // Barre de catégories
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip('Toutes', true, () {
                      // Logique pour afficher toutes les catégories
                    }),
                    _buildCategoryChip('Urgent', false, () {
                      // Logique pour filtrer par urgent
                    }),
                    _buildCategoryChip('Information', false, () {
                      // Logique pour filtrer par information
                    }),
                    _buildCategoryChip('Événement', false, () {
                      // Logique pour filtrer par événement
                    }),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: (() {
                    final normalized = _normalizeCategory(category);
                    final candidates = {category, normalized}.toList();
                    return FirebaseFirestore.instance
                        .collection('messages')
                        .where('categories', arrayContainsAny: candidates)
                        .orderBy('createdAt', descending: true)
                        .snapshots();
                  })(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingShimmer();
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Erreur de chargement des annonces',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
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
                      return _buildEmptyState();
                    }

                    // Filtrer par recherche si nécessaire
                    final filteredDocs = _searchQuery.isEmpty
                        ? docs
                        : docs.where((doc) {
                            final data = doc.data();
                            final title = (data['text'] ?? '')
                                .toString()
                                .toLowerCase();
                            final author = (data['authorName'] ?? '')
                                .toString()
                                .toLowerCase();
                            return title.contains(_searchQuery) ||
                                author.contains(_searchQuery);
                          }).toList();

                    if (filteredDocs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        // Rafraîchir les données
                        setState(() {});
                        return Future.delayed(const Duration(seconds: 1));
                      },
                      color: _primaryColor,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data();
                          final isNew = !_seenIds.contains(
                            filteredDocs[index].id,
                          );
                          return _buildAnnouncementCard(data, isNew);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        backgroundColor: _primaryColor,
        child: const Icon(Icons.arrow_upward, color: Colors.white),
      ),
    );
  }
}

class AudioAnnouncementTile extends StatefulWidget {
  final String url;
  final String authorName;
  final String? authorPhotoUrl;
  final DateTime? timestamp;
  final bool showAuthor;

  const AudioAnnouncementTile({
    super.key,
    required this.url,
    required this.authorName,
    this.authorPhotoUrl,
    this.timestamp,
    this.showAuthor = true,
  });

  @override
  State<AudioAnnouncementTile> createState() => _AudioAnnouncementTileState();
}

class _AudioAnnouncementTileState extends State<AudioAnnouncementTile> {
  final _player = AudioPlayer();
  bool _loading = true;
  bool _isPlaying = false;
  String? _error;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDragging = false;
  final _primaryColor = const Color(0xFF4F6F52);

  @override
  void initState() {
    super.initState();
    _init();
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _player.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });

    _player.positionStream.listen((position) {
      if (mounted && !_isDragging) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.tryParse(widget.url);
      final isHttp = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
      final supportedExt = uri != null && RegExp(r"\.(mp3|m4a|aac|wav|ogg)", caseSensitive: false).hasMatch(uri.path);
      if (!isHttp || !supportedExt) {
        throw Exception('Format ou URL audio non pris en charge');
      }
      await _player.setUrl(uri.toString());
      _duration = _player.duration ?? Duration.zero;
    } catch (e) {
      debugPrint('Erreur de chargement audio: $e');
      if (mounted) {
        setState(() => _error = 'Impossible de charger l\'audio');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_loading) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));

    if (d.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.timestamp != null
        ? widget.timestamp!.toString()
        : '';
    if (_loading) {
      return ListTile(
        leading: CircleAvatar(
          child: const Icon(Icons.campaign),
          backgroundImage:
              (widget.authorPhotoUrl != null &&
                  widget.authorPhotoUrl!.isNotEmpty)
              ? NetworkImage(widget.authorPhotoUrl!)
              : null,
        ),
        title: Text(
          widget.authorName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[100]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_error!, style: TextStyle(color: Colors.red[800])),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isPlaying ? _primaryColor.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPlaying
              ? _primaryColor.withOpacity(0.3)
              : Colors.grey[200]!,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showAuthor) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: widget.authorPhotoUrl != null
                      ? NetworkImage(widget.authorPhotoUrl!)
                      : null,
                  child: widget.authorPhotoUrl == null
                      ? const Icon(Icons.volume_up, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (widget.timestamp != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM, HH:mm').format(widget.timestamp!),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Barre de lecture
          Row(
            children: [
              // Bouton lecture/pause
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Barre de progression
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre de progression
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _primaryColor,
                        inactiveTrackColor: Colors.grey[300],
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                          pressedElevation: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        thumbColor: _primaryColor,
                        overlayColor: _primaryColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        min: 0,
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          setState(() {
                            _position = Duration(seconds: value.toInt());
                            _isDragging = true;
                          });
                        },
                        onChangeEnd: (value) async {
                          await _player.seek(Duration(seconds: value.toInt()));
                          setState(() => _isDragging = false);
                        },
                      ),
                    ),

                    // Temps
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
