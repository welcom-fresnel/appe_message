import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hermin/services/conversation_service.dart';
import '../ui/components/state_widgets.dart';
import '../ui/layouts/app_page_scaffold.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<File> _selectedImages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ConversationService.instance.markConversationAsRead(widget.conversationId, uid);
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _selectedImages.add(File(picked.path)));
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || (_ctrl.text.trim().isEmpty && _selectedImages.isEmpty)) return;

    setState(() => _sending = true);
    try {
      if (_selectedImages.isNotEmpty) {
        await ConversationService.instance.sendImageMessage(
          conversationId: widget.conversationId,
          senderId: uid,
          images: _selectedImages,
        );
        _selectedImages.clear();
      }
      if (_ctrl.text.trim().isNotEmpty) {
        await ConversationService.instance.sendMessage(
          conversationId: widget.conversationId,
          senderId: uid,
          text: _ctrl.text.trim(),
          type: 'text',
        );
        _ctrl.clear();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPageScaffold(
      title: widget.title,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ConversationService.instance.messagesStream(widget.conversationId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const AppSkeleton(count: 8);
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final isMe = d['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    final text = (d['text'] as String?) ?? '';
                    final media = (d['mediaUrls'] as List?)?.cast<String>() ?? [];
                    final createdAt = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? cs.primaryContainer : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (text.isNotEmpty) Text(text),
                              for (final url in media)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(url, height: 160, width: 220, fit: BoxFit.cover),
                                  ),
                                ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _selectedImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_selectedImages[i], width: 120, height: 84, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _selectedImages.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                children: [
                  IconButton(onPressed: _pickImage, icon: const Icon(Icons.image_outlined)),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Ecrire un message...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




