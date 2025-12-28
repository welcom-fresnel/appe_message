import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hermin/services/conversation_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;

  const ChatScreen({super.key, required this.conversationId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<File> _selectedImages = [];
  bool _sending = false;

  Future<void> _pickImage() async {
    final p = ImagePicker();
    final picked = await p.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _selectedImages.add(File(picked.path)));
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_ctrl.text.trim().isEmpty && _selectedImages.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_selectedImages.isNotEmpty) {
        await ConversationService.instance.sendImageMessage(conversationId: widget.conversationId, senderId: uid, images: _selectedImages);
        _selectedImages.clear();
      }
      if (_ctrl.text.trim().isNotEmpty) {
        await ConversationService.instance.sendMessage(conversationId: widget.conversationId, senderId: uid, text: _ctrl.text.trim(), type: 'text');
        _ctrl.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ConversationService.instance.messagesStream(widget.conversationId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final isMe = d['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    final text = (d['text'] as String?) ?? '';
                    final media = (d['mediaUrls'] as List?)?.cast<String>() ?? [];
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (text.isNotEmpty) Text(text),
                            for (final url in media)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url, height: 160, width: 220, fit: BoxFit.cover),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              d['createdAt'] is Timestamp
                                  ? (d['createdAt'] as Timestamp).toDate().toLocal().toString()
                                  : '',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedImages[i], width: 120, height: 84, fit: BoxFit.cover)),
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
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _selectedImages.length,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: Row(
                children: [
                  IconButton(onPressed: _pickImage, icon: const Icon(Icons.image)),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(hintText: 'Écrire un message...'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator())
                      : IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    // mark conversation as read when opening
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).set({
        'lastRead': {uid: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore
    }
  }
}
