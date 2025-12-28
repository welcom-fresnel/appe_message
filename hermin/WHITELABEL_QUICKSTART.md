# ⚡ Quick Start - White Label

Guide rapide pour ajouter un nouveau client en 5 minutes !

## 🚀 Ajouter un nouveau client (clientC)

### 1️⃣ Créer le fichier d'environnement (30 secondes)

```bash
# Copier le template
cp environments/env.clientA.example environments/.env.clientC

# Éditer avec vos valeurs
# APP_NAME=App Client C
# CLOUDINARY_CLOUD_NAME=...
# etc.
```

### 2️⃣ Créer le dossier Firebase (30 secondes)

```bash
mkdir android/app/src/clientC
```

### 3️⃣ Ajouter google-services.json (2 minutes)

1. Console Firebase → Ajouter une app Android
2. Package name: `com.hermine.hermin.clientC`
3. Télécharger `google-services.json`
4. Placer dans `android/app/src/clientC/`

### 4️⃣ Ajouter le flavor Android (1 minute)

Éditer `android/app/build.gradle.kts` :

```kotlin
productFlavors {
    // ... flavors existants ...
    
    create("clientC") {
        dimension = "client"
        applicationIdSuffix = ".clientC"
        resValue("string", "app_name", "App Client C")
    }
}
```

### 5️⃣ Tester ! (1 minute)

```bash
flutter run --flavor clientC --dart-define=FLAVOR=clientC
```

---

## ✅ C'est tout !

Votre nouveau client est prêt. L'application va automatiquement :
- Utiliser son propre Firebase
- Utiliser ses propres clés Cloudinary
- Afficher son nom personnalisé

---

## 📦 Build pour production

```bash
# APK
flutter build apk --flavor clientC --dart-define=FLAVOR=clientC --release

# App Bundle (Play Store)
flutter build appbundle --flavor clientC --dart-define=FLAVOR=clientC --release
```

---

## 🔍 Vérifications

- [ ] L'app se lance sans erreur
- [ ] Le nom de l'app est correct (dans la barre de titre)
- [ ] L'authentification Firebase fonctionne
- [ ] L'upload d'images Cloudinary fonctionne
- [ ] Les notifications fonctionnent

---

**📖 Guide complet : `README_WHITELABEL.md`**

