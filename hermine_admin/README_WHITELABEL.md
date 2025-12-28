# Guide de Configuration White-Label (hermine_admin)

Ce guide explique comment configurer et déployer le panneau d'administration pour un nouveau client en utilisant une base de code unique.

## Principe

Chaque client (ou "Flavor") aura son propre backend Firebase et ses propres configurations (clés d'API, etc.), mais la base de code reste identique.

---

## Étape 1: Prérequis

Pour chaque nouveau client (par exemple, `clientA`), vous devez utiliser le **même projet Firebase** que celui créé pour l'application mobile `hermin`.

1.  Dans ce projet Firebase, allez dans "Project Settings" et ajoutez une **application Web**.
2.  Copiez l'objet de configuration `firebaseConfig`. Il ressemble à ceci :
    ```javascript
    var firebaseConfig = {
      apiKey: "...",
      authDomain: "...",
      projectId: "...",
      // ...
    };
    ```

---

## Étape 2: Configuration des Fichiers d'Environnement

1.  **Ajoutez la dépendance** `flutter_dotenv: ^5.1.0` dans `pubspec.yaml`.

2.  **Créez un dossier `environments`** à la racine du projet.

3.  **Créez un fichier `.env` pour chaque client** dans ce dossier. Par exemple, `environments/.env.clientA`.

    **Exemple de contenu pour `environments/.env.clientA`:**
    ```
    # Configuration générale
    APP_NAME=Admin Client A
    
    # Configuration Firebase (copiée depuis la console)
    FIREBASE_API_KEY=...
    FIREBASE_AUTH_DOMAIN=...
    FIREBASE_PROJECT_ID=...
    FIREBASE_STORAGE_BUCKET=...
    FIREBASE_MESSAGING_SENDER_ID=...
    FIREBASE_APP_ID=...
    ```

---

## Étape 3: Initialisation Dynamique de Firebase

L'initialisation de Firebase doit être rendue dynamique pour utiliser les clés du fichier `.env`. Le `main.dart` sera modifié pour charger ces variables avant d'initialiser Firebase.

---

## Étape 4: Compiler et Déployer un Flavor

Utilisez la commande `flutter build web` avec l'option `--dart-define` pour spécifier le client.

**Pour compiler pour `clientA`:**
```sh
flutter build web --dart-define=FLAVOR=clientA
```

Lors du déploiement sur Netlify (ou un autre service), vous devrez configurer cette commande de build.

**Pour exécuter localement :**
```sh
flutter run -d chrome --dart-define=FLAVOR=clientA
```

Cette commande va charger les variables de `environments/.env.clientA` et les utiliser pour configurer l'application et Firebase.
