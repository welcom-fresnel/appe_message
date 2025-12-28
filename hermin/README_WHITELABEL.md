# 🎨 Guide de Configuration White-Label (Marque Blanche)

Ce guide explique comment configurer et compiler l'application `hermin` pour un nouveau client en utilisant une base de code unique. L'approche repose sur les **Flavors** de Flutter et les **fichiers d'environnement**.

## 🎯 Principe

Chaque client (ou "Flavor") aura son propre :
- ✅ Backend Firebase (base de données, authentification, stockage, etc.)
- ✅ Fichiers de configuration spécifiques (clés d'API, nom de l'application, etc.)
- ✅ Icône et nom d'application personnalisés
- ✅ Configuration Cloudinary dédiée

**La base de code Dart reste identique pour tous les clients !**

---

## 📋 Étape 1: Prérequis

Pour chaque nouveau client (par exemple, `clientC`), vous devez créer :

1. **Un projet Firebase** : 
   - Créez un nouveau projet sur la [console Firebase](https://console.firebase.google.com/)
   - Activez Authentication, Firestore, Storage, Cloud Messaging
   - Téléchargez le fichier `google-services.json`

2. **Un compte Cloudinary** (optionnel) : 
   - Créez un compte sur [Cloudinary](https://cloudinary.com/)
   - Notez le Cloud Name, Upload Preset, API Key et API Secret

---

## 🔧 Étape 2: Configuration des Fichiers d'Environnement

### 2.1 Créer le fichier .env

1. Copiez le fichier d'exemple :
   ```bash
   cp environments/env.clientA.example environments/.env.clientC
   ```

2. Éditez `environments/.env.clientC` avec vos vraies valeurs :
   ```env
   # Configuration Client C
   APP_NAME=App Client C
   
   # Configuration Cloudinary pour Client C
   CLOUDINARY_CLOUD_NAME=votre-cloud-name
   CLOUDINARY_UPLOAD_PRESET=votre-upload-preset
   CLOUDINARY_API_KEY=votre-api-key
   CLOUDINARY_API_SECRET=votre-api-secret
   ```

### 2.2 Vérification

Le package `flutter_dotenv: ^6.0.0` est déjà configuré dans `pubspec.yaml` et les fichiers `.env.*` sont déjà dans les assets.

---

## 🔥 Étape 3: Configuration de Firebase (Android)

### 3.1 Créer le dossier du flavor

```bash
mkdir android/app/src/clientC
```

### 3.2 Ajouter google-services.json

1. Dans la console Firebase, ajoutez une application Android
2. **Package name** : `com.hermine.hermin.clientC` (important !)
3. Téléchargez `google-services.json`
4. Placez-le dans `android/app/src/clientC/google-services.json`

### 3.3 Vérifier le package name

Ouvrez `google-services.json` et vérifiez que le `package_name` correspond :
```json
{
  "client": [{
    "client_info": {
      "android_client_info": {
        "package_name": "com.hermine.hermin.clientC"
      }
    }
  }]
}
```

---

## 🏗️ Étape 4: Configuration des Flavors (Android)

Modifiez le fichier `android/app/build.gradle.kts` :

```kotlin
android {
    // ... autres configurations ...

    // Configuration des Flavors pour White-Label
    flavorDimensions += "client"
    productFlavors {
        create("dev") {
            dimension = "client"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Hermin Dev")
        }
        create("clientA") {
            dimension = "client"
            applicationIdSuffix = ".clientA"
            resValue("string", "app_name", "App Client A")
        }
        create("clientB") {
            dimension = "client"
            applicationIdSuffix = ".clientB"
            resValue("string", "app_name", "App Client B")
        }
        // Ajoutez votre nouveau client ici
        create("clientC") {
            dimension = "client"
            applicationIdSuffix = ".clientC"
            resValue("string", "app_name", "App Client C")
        }
    }
}
```

---

## 💻 Étape 5: Code déjà configuré

Le fichier `lib/main.dart` est **déjà configuré** pour charger automatiquement le bon fichier `.env` :

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger l'environnement en fonction du Flavor
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  await dotenv.load(fileName: 'environments/.env.$flavor');

  await Firebase.initializeApp();
  // ... reste du code
}
```

Le `CloudinaryService` utilise également les variables d'environnement :
```dart
String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'default';
String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'default';
```

---

## 🚀 Étape 6: Compiler et Exécuter un Flavor

### Mode Debug (développement)

**Pour le flavor dev :**
```bash
flutter run --flavor dev --dart-define=FLAVOR=dev
```

**Pour clientA :**
```bash
flutter run --flavor clientA --dart-define=FLAVOR=clientA
```

**Pour clientB :**
```bash
flutter run --flavor clientB --dart-define=FLAVOR=clientB
```

**Pour clientC (nouveau) :**
```bash
flutter run --flavor clientC --dart-define=FLAVOR=clientC
```

### Mode Release (production)

**Build APK :**
```bash
flutter build apk --flavor clientA --dart-define=FLAVOR=clientA --release
```

**Build App Bundle (pour Play Store) :**
```bash
flutter build appbundle --flavor clientA --dart-define=FLAVOR=clientA --release
```

---

## 📱 Résultat

Chaque flavor va automatiquement :
- ✅ Utiliser le bon `google-services.json` (Firebase du client)
- ✅ Définir le nom de l'application (ex: "App Client A")
- ✅ Définir l'ID de l'application (ex: `com.hermine.hermin.clientA`)
- ✅ Charger les variables de `environments/.env.clientA`
- ✅ Utiliser les bonnes clés Cloudinary

---

## 🔒 Sécurité

### Fichiers ignorés par Git

Les fichiers suivants sont automatiquement ignorés (voir `.gitignore`) :
- `environments/.env.*` (sauf `.example`)
- `**/google-services.json` (sauf `.example`)

**⚠️ Ne JAMAIS commiter ces fichiers dans git !**

### Partage des configurations

Pour partager une configuration avec un client :
1. Envoyez-lui le fichier `.env.clientX` de manière sécurisée
2. Envoyez-lui le fichier `google-services.json` de manière sécurisée
3. Ne les envoyez JAMAIS par email non chiffré

---

## 📚 Checklist pour un nouveau client

- [ ] Créer un projet Firebase
- [ ] Télécharger `google-services.json`
- [ ] Créer `environments/.env.clientX`
- [ ] Créer le dossier `android/app/src/clientX/`
- [ ] Placer `google-services.json` dans ce dossier
- [ ] Ajouter le flavor dans `build.gradle.kts`
- [ ] Tester avec `flutter run --flavor clientX --dart-define=FLAVOR=clientX`
- [ ] Vérifier que l'app se lance correctement
- [ ] Vérifier que le nom de l'app est correct
- [ ] Tester l'authentification Firebase
- [ ] Tester l'upload Cloudinary
- [ ] Build en release et tester sur un appareil réel

---

## 🐛 Troubleshooting

### Erreur "File not found: environments/.env.xxx"
➡️ Vérifiez que le fichier `.env.xxx` existe et que le nom correspond au flavor

### Erreur "No matching client found for package name"
➡️ Vérifiez que le package name dans `google-services.json` correspond à `com.hermine.hermin.xxx`

### Erreur "CLOUDINARY_CLOUD_NAME is null"
➡️ Vérifiez que le fichier `.env.xxx` contient bien `CLOUDINARY_CLOUD_NAME=...`

### L'app ne se lance pas
➡️ Nettoyez le projet : `flutter clean && flutter pub get`

---

## 📖 Documentation supplémentaire

- `environments/README.md` - Guide des fichiers d'environnement
- `android/app/src/README.md` - Guide de la structure des flavors
- `QUICK_START.md` - Guide d'utilisation des services
- `ARCHITECTURE.md` - Architecture de l'application

---

**✨ Voilà ! Votre système white-label est maintenant configuré et prêt à l'emploi !**
