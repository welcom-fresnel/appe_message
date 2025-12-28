# Configuration des Flavors Android

Ce dossier contient les configurations spécifiques pour chaque flavor (client).

## 📁 Structure

```
src/
├── main/              # Code partagé par tous les flavors
├── dev/               # Configuration pour le flavor dev
│   └── google-services.json
├── clientA/           # Configuration pour le flavor clientA
│   └── google-services.json
└── clientB/           # Configuration pour le flavor clientB
    └── google-services.json
```

## 🔧 Configuration pour un nouveau flavor

Pour chaque flavor, vous devez :

1. **Créer un projet Firebase** pour ce client
2. **Télécharger `google-services.json`** depuis la console Firebase
3. **Placer le fichier** dans le dossier correspondant (ex: `src/clientA/google-services.json`)
4. **Vérifier le package name** dans le fichier correspond à celui défini dans `build.gradle.kts`

### Package names attendus :

- `dev` → `com.hermine.hermin.dev`
- `clientA` → `com.hermine.hermin.clientA`
- `clientB` → `com.hermine.hermin.clientB`

## ⚠️ Important

- Les fichiers `google-services.json` sont ignorés par git (sécurité)
- Chaque flavor doit avoir son propre projet Firebase
- Le package name doit correspondre exactement à celui configuré dans Firebase

## 📝 Exemple de fichiers

Des fichiers `.example` sont fournis comme modèles. Renommez-les en `google-services.json` après avoir ajouté vos vraies valeurs Firebase.

