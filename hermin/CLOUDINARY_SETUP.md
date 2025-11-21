# ✅ Guide de configuration Cloudinary

## 🎯 Le problème des images qui ne s'affichent pas

Les images ne s'affichent probablement pas parce que:

1. **Le preset `hermine_unsigned_images` n'existe pas** ← Cause la plus courante
2. **Les URLs sont mal formatées**
3. **Firestore stocke les mauvaises données**
4. **CORS non configuré**

---

## 🚀 Solution: Configuration Cloudinary

### Étape 1: Accéder à Cloudinary Console

1. Va sur https://cloudinary.com/console
2. Connecte-toi avec ton compte
3. Note ton **Cloud Name**: `dfw0pwwdr` ✓ (correct dans le code)

### Étape 2: Vérifier/Créer le Preset

1. **Aller dans Settings**
   - Clique sur la roue ⚙️ (Settings) en haut à droite
   - Cherche "Upload"

2. **Aller à Upload → Unsigned Presets**
   ![](https://res.cloudinary.com/dfw0pwwdr/image/upload/v1699870000/uploads_section.png)

3. **Vérifier que le preset existe**
   - Cherche `hermine_unsigned_images`
   - Si elle n'existe pas → Créer

### Étape 3: Créer le Preset (si n'existe pas)

1. **Clique sur "Add unsigned preset"**

2. **Configure:**
   - **Nom**: `hermine_unsigned_images`
   - **Mode**: Unsigned (c'est ce qu'on veut)
   - **Resource type**: Image
   - **Transformations** (optionnel):
     - Folder: `hermin/posts`
     - Format: Auto
     - Quality: Auto

3. **Save**

### Étape 4: Tester l'upload

Copie ce code dans dart pad ou ton app pour tester:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

void testCloudinaryUpload() async {
  try {
    print('🧪 Test upload Cloudinary...');
    
    // Créer un fichier de test (1x1 pixel PNG)
    final testBytes = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB4, 0x00, 0x00, 0x00,
      0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ];

    // Créer la requête
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/dfw0pwwdr/auto/upload'),
    );

    // Ajouter le fichier test
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        Uint8List.fromList(testBytes),
        filename: 'test.png',
      ),
    );

    // Ajouter le preset
    request.fields['upload_preset'] = 'hermine_unsigned_images';

    // Envoyer
    print('📤 Envoi vers Cloudinary...');
    final streamResponse = await request.send();
    final response = await http.Response.fromStream(streamResponse);

    print('📊 Status: ${response.statusCode}');
    print('📄 Response: ${response.body}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      print('✅ SUCCÈS! URL: ${json['secure_url']}');
    } else {
      print('❌ ERREUR! ${response.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
```

### Étape 5: Interpréter les résultats

**✅ Si succès (200):**
```json
{
  "public_id": "hermin/posts/abc123",
  "secure_url": "https://res.cloudinary.com/dfw0pwwdr/image/upload/v1699870000/hermin/posts/abc123.png",
  "width": 1,
  "height": 1,
  "format": "png",
  "bytes": 67
}
```
→ **Le preset fonctionne!** ✅

**❌ Si erreur 401/403:**
```json
{
  "error": {
    "message": "Invalid unsigned preset"
  }
}
```
→ **Le preset n'existe pas ou est mal configuré** ❌

**❌ Si erreur 404:**
```json
{
  "error": {
    "message": "Not found"
  }
}
```
→ **Cloud Name est incorrect** ❌

---

## 🔧 Configuration CORS (si besoin)

Si les images ne chargent pas dans l'app (erreur CORS):

1. **Aller dans Settings → Upload**
2. **Chercher "Allowed fetch domains"**
3. **Ajouter:**
   - `localhost:*`
   - Ton domaine (si te l'as)

---

## 📱 Test dans l'app

Une fois Cloudinary configuré, teste directement dans l'app:

```dart
import 'services/index.dart';

// Teste le service CloudinaryService
void debugUpload() async {
  final file = File('path/to/image.jpg');
  
  final response = await CloudinaryService.instance.uploadImage(file);
  
  if (response != null) {
    print('✅ URL: ${response.secureUrl}');
    print('✅ Optimized: ${response.getOptimizedUrl(width: 800)}');
  } else {
    print('❌ Upload failed');
  }
}
```

---

## 📋 Checklist

- [ ] J'ai accès à https://cloudinary.com/console
- [ ] Mon Cloud Name est `dfw0pwwdr`
- [ ] Le preset `hermine_unsigned_images` existe
- [ ] J'ai testé le preset avec curl/Postman
- [ ] Le status code est 200
- [ ] Cloudinary me retourne une URL valide
- [ ] Je peux accéder à l'URL dans mon navigateur
- [ ] L'image s'affiche dans mon navigateur
- [ ] Image.network() charge l'URL dans l'app

---

## 🎉 Une fois tout configuré

Ton code fonctionnera comme ça:

1. Utilisateur choisit image
2. Click "Publier"
3. CloudinaryService.uploadImage() envoie à Cloudinary
4. Cloudinary retourne URL
5. Code sauvegarde URL dans Firestore
6. FeedScreen lit depuis Firestore
7. Image.network() charge et affiche l'image ✅

---

**Besoin d'aide?** Vérifies le `CLOUDINARY_DEBUG.md` pour plus de détails!
