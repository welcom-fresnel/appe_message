import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'chat_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color _primaryColor = Colors.blue[700]!;
  final Color _accentColor = Colors.blue[100]!;
  final Color _backgroundColor = Colors.white;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  DocumentReference<Map<String, dynamic>>? _userRef;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  String _resolvedDisplayName() {
    final dn = (_data?['displayName'] as String?)?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final username = (_data?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    final first = (_data?['firstName'] as String?)?.trim() ?? '';
    final last = (_data?['lastName'] as String?)?.trim() ?? '';
    final full = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
    if (full.isNotEmpty) return full;
    final email = (_data?['email'] as String?) ?? '';
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Votre nom';
  }

  String _resolvedPhotoUrl() {
    final photoUrl = (_data?['photoUrl'] as String?)?.trim();
    final authorPhotoUrl = (_data?['authorPhotoUrl'] as String?)?.trim();
    return (photoUrl?.isNotEmpty ?? false) ? photoUrl! : (authorPhotoUrl ?? '');
  }

  String _resolvedRole() {
    final role = (_data?['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) return role;
    final category = (_data?['category'] as String?)?.trim();
    if (category != null && category.isNotEmpty) return category;
    return 'Votre poste';
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      _load();
    } else {
      _error = 'Utilisateur non authentifié';
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _userRef!.get();
      _data = snap.data() ?? <String, dynamic>{};
    } catch (e) {
      _error = 'Erreur de chargement du profil';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    if (_userRef == null) return;
    try {
      await _userRef!.set(patch, SetOptions(merge: true));
      _data = {...?_data, ...patch};
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil mis à jour'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Échec de la mise à jour'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email introuvable. Définissez-le dans le profil.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de réinitialisation envoyé à $email'),
            backgroundColor: _primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'envoi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editText({
    required String title,
    required String field,
    String? initial,
    int maxLines = 1,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _save({field: controller.text.trim()});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                      ),
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editChips({
    required String title,
    required String field,
    List<String> initial = const [],
    String addHint = 'Ajouter...',
  }) async {
    final chips = [...initial];
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setM) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in chips)
                        InputChip(
                          label: Text(c),
                          onDeleted: () => setM(() => chips.remove(c)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: addHint,
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (v) {
                            final val = v.trim();
                            if (val.isNotEmpty && !chips.contains(val)) {
                              setM(() => chips.add(val));
                              controller.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final val = controller.text.trim();
                          if (val.isNotEmpty && !chips.contains(val)) {
                            setM(() => chips.add(val));
                            controller.clear();
                          }
                        },
                        icon: Icon(Icons.add, color: _primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _save({field: chips});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                          ),
                          child: const Text('Enregistrer'),
                        ),
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
  }

  Widget _buildHeader() {
    final displayName = _resolvedDisplayName();
    final role = _resolvedRole();
    final photoUrl = _resolvedPhotoUrl();
    final verifiedEmail = (_data?['verified']?['email'] as bool?) ?? false;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, _primaryColor.withOpacity(0.85)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: _accentColor,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 34, color: Colors.white)
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (verifiedEmail)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.verified, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Vérifié',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _editText(
              title: 'Nom affiché',
              field: 'displayName',
              initial: displayName,
              hint: 'Entrez votre nom complet',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Éditer'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    VoidCallback? onEdit,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit, size: 16, color: _primaryColor),
                    label: Text(
                      'Modifier',
                      style: TextStyle(color: _primaryColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final summary = (_data?['summary'] as String?)?.trim() ?? '';
    return _sectionCard(
      title: 'Résumé professionnel',
      onEdit: () => _editText(
        title: 'Résumé professionnel',
        field: 'summary',
        initial: summary,
        maxLines: 5,
        hint: 'Décrivez brièvement votre expérience et vos objectifs.',
      ),
      children: [
        Text(
          summary.isNotEmpty
              ? summary
              : 'Ajoutez un résumé pour mettre en valeur votre profil.',
          style: TextStyle(color: Colors.grey[800], height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPersonal() {
    final city = (_data?['location']?['city'] as String?)?.trim() ?? '';
    final country = (_data?['location']?['country'] as String?)?.trim() ?? '';
    final tz = (_data?['location']?['timezone'] as String?)?.trim() ?? '';
    return _sectionCard(
      title: 'Informations personnelles',
      onEdit: () async {
        await _editText(
          title: 'Ville',
          field: 'location.city',
          initial: city,
          hint: 'Ville',
        );
        await _editText(
          title: 'Pays',
          field: 'location.country',
          initial: country,
          hint: 'Pays',
        );
        await _editText(
          title: 'Fuseau horaire',
          field: 'location.timezone',
          initial: tz,
          hint: 'Ex: Europe/Paris',
        );
        await _load();
      },
      children: [
        _kv('Ville', city.isNotEmpty ? city : '—'),
        _kv('Pays', country.isNotEmpty ? country : '—'),
        _kv('Fuseau horaire', tz.isNotEmpty ? tz : '—'),
      ],
    );
  }

  Widget _buildContacts() {
    final email = (_data?['contacts']?['email'] as String?)?.trim() ?? '';
    final phone = (_data?['contacts']?['phone'] as String?)?.trim() ?? '';
    final linkedin =
        (_data?['contacts']?['links']?['linkedin'] as String?)?.trim() ?? '';
    final github =
        (_data?['contacts']?['links']?['github'] as String?)?.trim() ?? '';
    final website =
        (_data?['contacts']?['links']?['website'] as String?)?.trim() ?? '';
    return _sectionCard(
      title: 'Coordonnées & Réseaux',
      onEdit: () async {
        await _editText(
          title: 'Email',
          field: 'contacts.email',
          initial: email,
          hint: 'email@exemple.com',
        );
        await _editText(
          title: 'Téléphone',
          field: 'contacts.phone',
          initial: phone,
          hint: '+33 ...',
        );
        await _editText(
          title: 'LinkedIn',
          field: 'contacts.links.linkedin',
          initial: linkedin,
          hint: 'URL LinkedIn',
        );
        await _editText(
          title: 'GitHub',
          field: 'contacts.links.github',
          initial: github,
          hint: 'URL GitHub',
        );
        await _editText(
          title: 'Site Web',
          field: 'contacts.links.website',
          initial: website,
          hint: 'https://',
        );
        await _load();
      },
      children: [
        _kv('Email', email.isNotEmpty ? email : '—'),
        _kv('Téléphone', phone.isNotEmpty ? phone : '—'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _linkChip('LinkedIn', linkedin),
            _linkChip('GitHub', github),
            _linkChip('Site', website),
          ],
        ),
      ],
    );
  }

  Widget _buildJob() {
    final role = (_data?['role'] as String?)?.trim() ?? '';
    final department = (_data?['department'] as String?)?.trim() ?? '';
    final mode = (_data?['workMode'] as String?)?.trim() ?? '';
    final availability = (_data?['availability'] as String?)?.trim() ?? '';
    return _sectionCard(
      title: 'Poste & Organisation',
      onEdit: () async {
        await _editText(
          title: 'Rôle/Poste',
          field: 'role',
          initial: role,
          hint: 'Ex: Développeur Flutter',
        );
        await _editText(
          title: 'Département',
          field: 'department',
          initial: department,
          hint: 'Ex: Produit',
        );
        await _editText(
          title: 'Mode de travail',
          field: 'workMode',
          initial: mode,
          hint: 'Présentiel / Hybrid / Remote',
        );
        await _editText(
          title: 'Disponibilité',
          field: 'availability',
          initial: availability,
          hint: 'Ex: 9h-18h, CET',
        );
        await _load();
      },
      children: [
        _kv('Rôle', role.isNotEmpty ? role : '—'),
        _kv('Département', department.isNotEmpty ? department : '—'),
        _kv('Mode', mode.isNotEmpty ? mode : '—'),
        _kv('Disponibilité', availability.isNotEmpty ? availability : '—'),
      ],
    );
  }

  Widget _buildSkills() {
    final skills = ((_data?['skills'] as List?)?.cast() ?? []).cast<Map?>();
    final flatSkills = <String>[];
    for (final s in skills) {
      final n = (s?['name'] as String?)?.trim();
      if (n != null && n.isNotEmpty) flatSkills.add(n);
    }
    final tags = ((_data?['tags'] as List?)?.cast() ?? []).cast<String>();
    return _sectionCard(
      title: 'Compétences & Intérêts',
      onEdit: () async {
        await _editChips(
          title: 'Compétences',
          field: 'skills',
          initial: flatSkills,
          addHint: 'Ajouter une compétence',
        );
        await _editChips(
          title: 'Intérêts',
          field: 'tags',
          initial: tags,
          addHint: 'Ajouter un intérêt',
        );
        await _load();
      },
      children: [
        Text(
          'Compétences',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _chipsOrEmpty(flatSkills),
        const SizedBox(height: 12),
        Text(
          'Intérêts',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _chipsOrEmpty(tags),
      ],
    );
  }

  Widget _buildPreferences() {
    final push =
        (_data?['preferences']?['notifications']?['push'] as bool?) ?? true;
    final email =
        (_data?['preferences']?['notifications']?['email'] as bool?) ?? false;
    final start = (_data?['preferences']?['dnd']?['start'] as String?) ?? '';
    final end = (_data?['preferences']?['dnd']?['end'] as String?) ?? '';
    return _sectionCard(
      title: 'Préférences & Notifications',
      children: [
        SwitchListTile(
          value: push,
          title: const Text('Notifications push'),
          onChanged: (v) => _save({
            'preferences': {
              'notifications': {'push': v},
            },
          }),
        ),
        SwitchListTile(
          value: email,
          title: const Text('Notifications email'),
          onChanged: (v) => _save({
            'preferences': {
              'notifications': {'email': v},
            },
          }),
        ),
        const SizedBox(height: 4),
        _kv('Ne pas déranger (début)', start.isNotEmpty ? start : '—'),
        _kv('Ne pas déranger (fin)', end.isNotEmpty ? end : '—'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await _editText(
                title: 'DND Début',
                field: 'preferences.dnd.start',
                initial: start,
                hint: 'Ex: 22:00',
              );
              await _editText(
                title: 'DND Fin',
                field: 'preferences.dnd.end',
                initial: end,
                hint: 'Ex: 07:00',
              );
              await _load();
            },
            icon: Icon(Icons.schedule, color: _primaryColor),
            label: Text(
              'Configurer DND',
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity() {
    final devices = ((_data?['security']?['devices'] as List?)?.cast() ?? [])
        .cast<Map?>();
    final twoFA = (_data?['security']?['twoFAEnabled'] as bool?) ?? false;
    return _sectionCard(
      title: 'Sécurité & Confidentialité',
      children: [
        SwitchListTile(
          value: twoFA,
          title: const Text('Double authentification (2FA)'),
          onChanged: (v) => _save({
            'security': {'twoFAEnabled': v},
          }),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_reset, color: _primaryColor),
          title: const Text('Changer le mot de passe'),
          subtitle: const Text(
            'Envoie un email de réinitialisation au compte connecté',
          ),
          onTap: _sendPasswordResetEmail,
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Appareils connectés',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (devices.isEmpty)
          Text(
            'Aucun appareil enregistré',
            style: TextStyle(color: Colors.grey[600]),
          )
        else
          ...devices.map((d) {
            final name = (d?['name'] as String?) ?? 'Appareil';
            final lastSeen = (d?['lastSeen'] as Timestamp?);
            final dt = lastSeen != null
                ? DateFormat('dd MMM yyyy, HH:mm').format(lastSeen.toDate())
                : '—';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_other),
              title: Text(name),
              subtitle: Text('Dernière activité: $dt'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Révoquer'),
              ),
            );
          }),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipsOrEmpty(List<String> items) {
    if (items.isEmpty) {
      return Text('Aucun élément', style: TextStyle(color: Colors.grey[600]));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (e) => Chip(
              label: Text(e),
              backgroundColor: _primaryColor.withOpacity(0.08),
              side: BorderSide(color: _primaryColor.withOpacity(0.15)),
            ),
          )
          .toList(),
    );
  }

  Widget _linkChip(String label, String url) {
    if (url.isEmpty) {
      return Chip(
        label: Text(label),
        backgroundColor: _primaryColor.withOpacity(0.06),
        side: BorderSide(color: _primaryColor.withOpacity(0.12)),
      );
    }
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.link, size: 16),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lien copié: $label'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryColor,
          ),
        );
      },
    );
  }

  Widget _buildPublicationsHistory() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return _sectionCard(
          title: 'Mes publications (${docs.length})',
          children: [
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Aucune publication',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final postId = docs[index].id;
                  final text = (data['text'] as String?) ?? '';
                  final mediaUrls =
                      (data['mediaUrls'] as List<dynamic>?)
                          ?.map((e) => e as String)
                          .toList() ??
                      [];
                  final imageUrl = (data['imageUrl'] as String?) ?? '';
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final likes = List<String>.from(data['likes'] ?? []);
                  final comments = List<String>.from(data['comments'] ?? []);
                  final formattedDate = createdAt != null
                      ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt)
                      : '—';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête avec date et bouton supprimer
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (text.isNotEmpty)
                                      Text(
                                        text.length > 100
                                            ? '${text.substring(0, 100)}...'
                                            : text,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
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
                              // Bouton supprimer
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[600],
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showDeletePublicationDialog(postId, text),
                              ),
                            ],
                          ),

                          // Image si présente
                          if (mediaUrls.isNotEmpty || imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                mediaUrls.isNotEmpty
                                    ? mediaUrls.first
                                    : imageUrl,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported),
                                      ),
                                    ),
                              ),
                            ),
                          ],

                          // Stats
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.favorite_outline,
                                size: 16,
                                color: Colors.red[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${likes.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.comment_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${comments.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showDeletePublicationDialog(
    String postId,
    String preview,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la publication?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Êtes-vous sûr de vouloir supprimer cette publication?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preview.length > 60
                    ? '${preview.substring(0, 60)}...'
                    : preview,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deletePublication(postId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePublication(String postId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Suppression en cours...'),
          backgroundColor: _primaryColor,
        ),
      );

      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Publication supprimée'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      body: _loading
          ? ListView.builder(
              itemCount: 5,
              itemBuilder: (context, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(height: 96, color: Colors.grey[100]),
              ),
            )
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: _primaryColor,
                    title: const Text('Profil'),
                    actions: [
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ChatListScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        tooltip: 'Messages',
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 12),
                      _buildSummary(),
                      _buildPersonal(),
                      _buildContacts(),
                      _buildJob(),
                      _buildSkills(),
                      _buildPreferences(),
                      _buildPublicationsHistory(),
                      _buildSecurity(),
                      const SizedBox(height: 28),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }
}
