# Fichiers d'environnement

Ce dossier contient les fichiers de configuration pour chaque client (flavor).

## 📝 Instructions

1. **Copier les fichiers d'exemple** :
   ```bash
   cp env.dev.example .env.dev
   cp env.clientA.example .env.clientA
   cp env.clientB.example .env.clientB
   ```

2. **Éditer les fichiers `.env.*`** avec les vraies valeurs :
   - Nom de l'application
   - Clés Cloudinary
   - Autres configurations

3. **Les fichiers `.env.*` sont ignorés par git** pour la sécurité.

## 🔐 Sécurité

**⚠️ IMPORTANT** : Ne JAMAIS commiter les fichiers `.env.*` dans git !

Les fichiers `.env.*` contiennent des clés d'API sensibles et doivent rester privés.

## ➕ Ajouter un nouveau client

Pour ajouter un nouveau client (ex: `clientC`) :

1. Créer `environments/.env.clientC` en utilisant `env.clientA.example` comme modèle
2. Configurer le flavor dans `android/app/build.gradle.kts`
3. Ajouter le dossier `android/app/src/clientC/` avec `google-services.json`
4. Compiler avec : `flutter run --flavor clientC --dart-define=FLAVOR=clientC`

