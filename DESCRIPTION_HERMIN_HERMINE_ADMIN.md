# Description du projet (dossiers `hermin` et `hermine_admin` uniquement)

Date d'observation: 2026-03-26 (Europe/Paris)
Portee: uniquement les dossiers `d:\app_message\hermin` et `d:\app_message\hermine_admin`, comme demande.

## Dossier `hermin`

### Nature
Projet Flutter (app mobile) nomme `hermin`.

### Arborescence observee (niveau 1)
```text
hermin/
  .dart_tool/
  android/
  assets/
  build/
  environments/
  functions/
  lib/
  test/
  .firebaserc
  .flutter-plugins-dependencies
  .gitignore
  .metadata
  analysis_options.yaml
  ARCHITECTURE.md
  AUDIO_PLAYBACK_ISSUE.md
  BADGE_NOTIFICATIONS.md
  CLOUDINARY_DEBUG.md
  CLOUDINARY_FIXED.md
  CLOUDINARY_SETUP.md
  COLOR_PALETTE.md
  COMMENTS_REPORT_FEATURE.md
  CORRECTIONS_APPLIQUEES.md
  firebase.json
  firestore.rules
  HARMONISATION_ANNONCES.md
  HARMONISATION_COULEURS.md
  IMPROVEMENTS.md
  pubspec.lock
  pubspec.yaml
  QUICK_START.md
  README.md
  README_REFACTORING.md
  README_WHITELABEL.md
  REFACTORING_EXAMPLES.md
  RESUME_MODIFICATIONS_FINALES.md
  SERVICES_GUIDE.md
  storage.rules
  TODO.md
  WHITELABEL_QUICKSTART.md
```

### `lib/` (code applicatif)
```text
lib/
  screens/
    announcements_screen.dart
    auth_screen.dart
    chat_list_screen.dart
    chat_screen.dart
    feed_screen.dart
    home_shell.dart
    profile_screen.dart
  services/
    auth_service.dart
    cloudinary_service.dart
    conversation_service.dart
    firebase_service.dart
    index.dart
    message_listener_service.dart
    message_service.dart
    notification_handler.dart
    user_service.dart
  ui/
    components/
      app_badged_icon.dart
      app_button.dart
      app_card.dart
      app_search_field.dart
      app_states.dart
      app_text_field.dart
      app_ui_states.dart
      state_widgets.dart
    layouts/
      app_page_scaffold.dart
    theme/
      app_theme.dart
      app_theme_extensions.dart
    ui.dart
  firebase_options.dart
  main.dart
  notification_service.dart
```

### `assets/`
```text
assets/
  img/
    hero-classroom.jpg
    icon.png
    icon_foreground.png
  sounds/
    bell.mp3
  hero-classroom.jpg
  icon.png
  icon_foreground.png
```

### `environments/`
```text
environments/
  .env.clientA
  .env.dev
  env.clientA.example
  env.clientB.example
  env.dev.example
  README.md
```

### `functions/` (Node/Firebase Functions)
```text
functions/
  node_modules/
  .eslintrc.js
  .gitignore
  index.js
  package-lock.json
  package.json
```

### Configuration Firebase
- `firebase.json`
- `firestore.rules`
- `storage.rules`
- `.firebaserc`

### Dependances principales (extrait de `pubspec.yaml`)
- Flutter + `cupertino_icons`
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`
- Audio: `record`, `just_audio`
- Permissions: `permission_handler`
- Navigation et state: `go_router`, `flutter_riverpod`
- Media et UI: `image_picker`, `shimmer`
- Notifications: `flutter_local_notifications`, `notification_listener_service`
- Divers: `http`, `intl`, `flutter_dotenv`

### Documentation interne (fichiers .md visibles)
- Guides et notes techniques (architecture, cloudinary, notifications, refactoring, etc.)
- Quickstarts et README (dont whitelabel)

## Dossier `hermine_admin`

### Nature
Projet Flutter (app admin) nomme `leaurry_floride` dans `pubspec.yaml`.

### Arborescence observee (niveau 1)
```text
hermine_admin/
  .dart_tool/
  .git/
  android/
  assets/
  build/
  lib/
  netlify/
  test/
  .firebaserc
  .flutter-plugins-dependencies
  .gitignore
  .metadata
  analysis_options.yaml
  firebase.json
  FIRESTORE_RULES.md
  netlify.toml
  package.json
  pubspec.lock
  pubspec.yaml
  README.md
  README_WHITELABEL.md
```

### `lib/`
```text
lib/
  screens/
    auth_screen.dart
    ChatScreen.dart
    compose_message_screen.dart
    dashboard_screen.dart
    feed_screen_admin.dart
    modern_dashboard.dart
    reception_screen.dart
    sent_messages_history_screen.dart
    settings_screen.dart
    stats_screen.dart
    users_management_screen.dart
    user_management_screen.dart
  services/
    admin_prefs_service.dart
    cloudinary_service.dart
    reception_service.dart
    sms_service.dart
  widgets/
    ConversationCard .dart
    post_media_carousel.dart
  config.dart
  firebase_options.dart
  main.dart
```

### `assets/`
```text
assets/
  icon.png
  icon_foreground.png
```

### `netlify/`
```text
netlify/
  functions/
    create-user.js
  node_modules/
  index.html
  package-lock.json
  package.json
```

### Configuration Firebase / Netlify
- `firebase.json`
- `.firebaserc`
- `FIRESTORE_RULES.md`
- `netlify.toml`

### Dependances principales (extrait de `pubspec.yaml`)
- Flutter + `cupertino_icons`
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `firebase_functions`
- Cloud Functions: `cloud_functions`
- Admin/telephonie: `telephony` (depuis `../packages/telephony_patched`)
- HTTP et data: `http`, `http_parser`, `path_provider`, `intl`
- UI/Charts: `fl_chart`
- Audio: `record`, `just_audio`
- Navigation et state: `go_router`, `flutter_riverpod`
- Media/env: `image_picker`, `flutter_dotenv`

## Remarques
- Les deux dossiers sont des projets Flutter distincts avec integration Firebase.
- `hermin` contient en plus un dossier `functions` Node (cloud functions) et de nombreux fichiers de documentation interne.
- `hermine_admin` contient en plus un dossier `netlify` avec une fonction `create-user.js`.

Fin du document.
