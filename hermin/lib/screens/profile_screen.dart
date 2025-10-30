import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  File? _avatar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    String fromDb = '';
    if (data != null) {
      final u = data['username'] as String?;
      final d = data['displayName'] as String?;
      fromDb = (u != null && u.isNotEmpty)
          ? u
          : (d ?? '');
    }
    _nameCtrl.text = fromDb.isNotEmpty ? fromDb : (user.displayName ?? '');
    setState(() {});
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _avatar = File(picked.path));
  }

  Future<String?> _uploadToCloudinary(File file) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/dfw0pwwdr/image/upload'),
    );
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    req.fields['upload_preset'] = 'hermine_unsigned_audio';
    final resp = await req.send();
    if (resp.statusCode == 200) {
      final body = await resp.stream.bytesToString();
      final jsonResp = jsonDecode(body);
      final secureUrl = (jsonResp['secure_url'] as String?) ?? '';
      return secureUrl.isNotEmpty
          ? secureUrl.replaceFirst('/upload/', '/upload/f_jpg/')
          : null;
    }
    return null;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    String? photoUrl = user.photoURL;
    if (_avatar != null) {
      photoUrl = await _uploadToCloudinary(_avatar!);
    }
    final name = _nameCtrl.text.trim();
    final parts = name.split(' ').where((e) => e.isNotEmpty).toList();
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': name,
        'displayName': name,
        'firstName': firstName,
        'lastName': lastName,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updateDisplayName(name);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);
      if (mounted) setState(() => _saving = false);
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final avatar = _avatar != null
        ? Image.file(_avatar!, width: 80, height: 80, fit: BoxFit.cover)
        : (user?.photoURL != null
            ? Image.network(user!.photoURL!, width: 80, height: 80, fit: BoxFit.cover)
            : const Icon(Icons.person, size: 80));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: avatar,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.camera_alt),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Se déconnecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
