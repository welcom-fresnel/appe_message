import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermine Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const DashboardScreen();
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
  final List<String> _allCategories = const ['parent', 'eleve', 'enseignant'];
  final Set<String> _selected = {'parent'};
  final TextEditingController _textCtrl = TextEditingController();
  bool _sending = false;
  bool _sendAlsoSms = false; // envoyer via SMS MTN
  // Cloudinary config (à renseigner)
  static const String CLOUD_NAME = 'dfw0pwwdr';
  static const String UPLOAD_PRESET = 'hermine_unsigned_audio';

  // Audio state
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploadingAudio = false;
  DateTime? _recordStart;
  String? _audioError;

  final telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    // Pré-demande de permissions pour que l'utilisateur voie le prompt au démarrage
    _ensureSmsPermissions();
  }

  Future<void> _sendTextMessage() async {
    if (_textCtrl.text.trim().isEmpty || _selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'categories': _selected.toList(),
        'type': 'text',
        'text': _textCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Envoi SMS local si coché
      if (_sendAlsoSms) {
        await _sendSmsBatch(_textCtrl.text.trim());
      }
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

  Future<bool> _ensureSmsPermissions() async {
    // Sur Android 6+, il faut les permissions runtime
    final smsStatus = await Permission.sms.status;
    final phoneStatus = await Permission.phone.status;

    if (smsStatus.isGranted && phoneStatus.isGranted) return true;

    final results = await [Permission.sms, Permission.phone].request();
    final ok = (results[Permission.sms]?.isGranted ?? false) &&
        (results[Permission.phone]?.isGranted ?? false);

    if (!ok) {
      if ((results[Permission.sms]?.isPermanentlyDenied ?? false) ||
          (results[Permission.phone]?.isPermanentlyDenied ?? false)) {
        await openAppSettings();
      }
    }
    return ok;
  }

  Future<void> _sendSmsBatch(String message) async {
    final ok = await _ensureSmsPermissions();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission SMS refusée')),
        );
      }
      return;
    }
    // Récupère les utilisateurs par catégories sélectionnées
    final qs = await FirebaseFirestore.instance
        .collection('users')
        .where('category', whereIn: _selected.toList())
        .get();
    final phones = <String>[];
    for (final d in qs.docs) {
      final m = d.data();
      final phone = (m['phone'] as String?)?.trim();
      final optIn = (m['smsOptIn'] as bool?) ?? true; // fallback true si absent
      if (optIn && phone != null && phone.isNotEmpty) {
        phones.add(phone);
      }
    }
    if (phones.isEmpty) return;
    // Envoi avec throttling léger
    for (final p in phones) {
      try {
        await telephony.sendSms(to: p, message: message, isMultipart: true);
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        // continue, on peut ajouter un log si besoin
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS envoyés à ${phones.length} destinataires')),
      );
    }
  }

  Future<String?> _uploadToCloudinary(File file) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$CLOUD_NAME/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = UPLOAD_PRESET
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

      // 1) créer le message audio d'abord pour conserver les métadonnées
      final msgRef = await FirebaseFirestore.instance.collection('messages').add({
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'categories': _selected.toList(),
        'type': 'audio',
        'audioFormat': 'aac',
        'durationSec': secs,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) upload Cloudinary
      final url = await _uploadToCloudinary(file);

      // 3) mise à jour du message
      await msgRef.update({'audioUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vocal envoyé')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _audioError = 'Erreur upload: $e');
    } finally {
      if (mounted) setState(() => _isUploadingAudio = false);
    }
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
      body: Padding(
        padding: const EdgeInsets.all(16),
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
            SwitchListTile(
              title: const Text('Envoyer aussi par SMS (MTN)'),
              subtitle: const Text('Envoi depuis la SIM de cet appareil'),
              value: _sendAlsoSms,
              onChanged: (v) => setState(() => _sendAlsoSms = v),
            ),
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
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MyHomePage(title: 'Hermine Admin Home');
        }
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Se connecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
