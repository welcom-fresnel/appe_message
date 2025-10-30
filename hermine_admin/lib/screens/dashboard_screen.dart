import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:telephony/telephony.dart';
import '../config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<String> _allCategories = const ['parent', 'eleve', 'enseignant'];
  final Set<String> _selected = {'parent'};
  final TextEditingController _textCtrl = TextEditingController();
  bool _sending = false;

  // Cloudinary (via config centralisée)

  // Audio state (record v6)
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploadingAudio = false;
  DateTime? _recordStart;
  String? _audioError;

  Future<void> _sendSmsToSelectedUsers(String text) async {
    try {
      final telephony = Telephony.instance;
      final granted = await telephony.requestPhoneAndSmsPermissions ?? false;
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission SMS refusée')),
          );
        }
        return;
      }
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('category', whereIn: _selected.toList())
          .get();
      for (final d in qs.docs) {
        final data = d.data();
        final phone = (data['phone'] ?? '').toString().trim();
        if (phone.isEmpty) continue;
        try {
          await telephony.sendSms(
            to: phone,
            message: text,
            isMultipart: text.length > 160,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _sendTextMessage() async {
    if (_textCtrl.text.trim().isEmpty || _selected.isEmpty) return;
    final text = _textCtrl.text.trim();
    setState(() => _sending = true);
    try {
      await _sendSmsToSelectedUsers(text);
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'categories': _selected.toList(),
        'type': 'text',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _textCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message envoyé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = 'audio'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('audio', 'mp4'),
      ));

    final res = await req.send();
    if (res.statusCode == 200) {
      final body = await res.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['secure_url'] as String?;
    } else {
      final err = await res.stream.bytesToString();
      throw Exception('Cloudinary error ${res.statusCode}: $err');
    }
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopAndUploadAudio();
      return;
    }
    _audioError = null;
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      setState(() => _audioError = 'Permission micro refusée');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      setState(() {
        _isRecording = true;
        _recordStart = DateTime.now();
      });
    } catch (e) {
      setState(() => _audioError = 'Erreur enregistrement: $e');
    }
  }

  Future<void> _stopAndUploadAudio() async {
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;
      final file = File(path);
      if (!file.existsSync()) return;
      final secs = _recordStart != null ? DateTime.now().difference(_recordStart!).inSeconds : null;
      setState(() => _isUploadingAudio = true);

      // 1) Créer le message audio
      final msgRef = await FirebaseFirestore.instance.collection('messages').add({
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'categories': _selected.toList(),
        'type': 'audio',
        'audioFormat': 'aac',
        'durationSec': secs,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) Upload Cloudinary
      final url = await _uploadToCloudinary(file);
      if (url == null || url.isEmpty) {
        throw Exception('URL Cloudinary vide');
      }

      // 3) Mise à jour du message
      await msgRef.update({'audioUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vocal envoyé')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _audioError = 'Erreur upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'upload audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //leading: Image.asset("assets/icon.png", width: 1, height: 5,),
        backgroundColor: const Color.fromARGB(255, 238, 198, 196),
        title: const Text('Hermine Admin'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      drawer:  Drawer(
        child: Column(
          children: [
            const DrawerHeader(child: Center(
              child: Text("Paramettre",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),),
            )),
            ListTile(
              leading: const Icon(Icons.person_2_rounded, color: Colors.lightGreen,),
              title: const Text("Profile"),
              subtitle: const Text("Modifier la photo de mon profile ..."),
              onTap: (){},
            ),
            ListTile(
              leading: const Icon(Icons.logout_outlined, color: Colors.green,),
              title: const Text("Connexion"),
              subtitle: const Text("Se deconnecter ..."),
              onTap: (){},
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Catégories'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _allCategories.map((c) {
                  final selected = _selected.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selected.add(c);
                        } else {
                          _selected.remove(c);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Message texte'),
              const SizedBox(height: 8),
              TextField(
                controller: _textCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Votre message...',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendTextMessage,
                  icon: _sending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Envoyer'),
                ),
              ),
              const SizedBox(height: 16),
              if (_selected.isEmpty)
                const Text('Sélectionnez une catégorie pour voir les utilisateurs')
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('category', whereIn: _selected.toList())
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Erreur lors du chargement des utilisateurs'),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Utilisateurs (${docs.length})'),
                        const SizedBox(height: 8),
                        ListView.builder(
                          itemCount: docs.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final d = docs[index];
                            final m = d.data();
                            final name = (m['name'] ?? m['displayName'] ?? m['phone'] ?? d.id).toString();
                            final phone = (m['phone'] ?? '').toString();
                            final category = (m['category'] ?? '').toString();
                            return ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(name),
                              subtitle: Text([phone, category].where((e) => e.isNotEmpty).join(' · ')),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Vocal (120s max)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_audioError != null) ...[
                Text(_audioError!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploadingAudio ? null : _toggleRecord,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'Arrêter et envoyer' : 'Enregistrer'),
                  ),
                  const SizedBox(width: 12),
                  if (_isRecording) const Text('Enregistrement...'),
                  if (_isUploadingAudio) const Text('  Upload...'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
