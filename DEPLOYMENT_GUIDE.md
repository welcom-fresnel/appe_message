# 🚀 Guide de déploiement - Correctif recherche d'utilisateurs

## ✅ Avant de déployer

- [ ] Tester la recherche dans l'app admin localement
- [ ] Vérifier que les nouveaux comptes peuvent être recherchés
- [ ] Vérifier le fallback pour les anciens comptes

---

## 📲 Déployer vers Firebase/Play Store

### Étape 1 : Build et déploiement hermin (app principale)

```bash
cd hermin

# Vérifier qu'il n'y a pas d'erreurs
flutter analyze

# Build APK pour test
flutter build apk --release

# Ou build le bundle pour Play Store
flutter build appbundle --release
```

**Changements** : `auth_screen.dart` - Ajout du champ `keywords` pour tous les nouveaux utilisateurs

### Étape 2 : Build et déploiement hermine_admin (app admin)

```bash
cd hermine_admin

# Vérifier qu'il n'y a pas d'erreurs
flutter analyze

# Build APK pour test
flutter build apk --release

# Ou build le bundle pour Play Store
flutter build appbundle --release
```

**Changements** : `compose_message_screen.dart` - Amélioration de la fonction de recherche

---

## 🔄 Rollout progressif recommandé

### Phase 1 : Test (24-48h)
```
- Déployer hermine_admin v1.X.X avec la nouvelle recherche
- Les utilisateurs existants utilisent le fallback ✅
- Les nouveaux utilisateurs testent les keywords
```

### Phase 2 : Production (rollout complet)
```
- Déployer hermin v1.X.X avec la génération de keywords
- Tous les nouveaux comptes ont les keywords ✅
```

### Phase 3 : Migration optionnelle
```
- Exécuter le script Cloud Function pour migrer les anciens utilisateurs
- Les keywords sont générés pour tous les comptes ⚡
```

---

## 🗄️ Firestore - Vérifier les données

### 1. Vérifier qu'un nouvel utilisateur a les keywords

```
Collection: users
Document: [uid]
Fields:
  - firstName: "Jean"
  - lastName: "Dupont"
  - keywords: ["jean", "j", "je", "jea", "dupont", "d", "du", ...] ✅
```

### 2. Vérifier la recherche sur la Firestore Console

```
Collection: users
Filter: keywords array-contains "jea"
→ Devrait afficher les utilisateurs avec "jean" ✅
```

---

## ⚠️ Troubleshooting

### La recherche ne fonctionne toujours pas

**Solution 1** : Vérifier que l'app admin est à jour
```bash
cd hermine_admin
flutter pub get
flutter run --release
```

**Solution 2** : Vérifier qu'un nouvel utilisateur a les keywords
```bash
# Dans Firestore Console
→ Chercher un utilisateur créé APRÈS le déploiement
→ Doit avoir le champ "keywords" ✅
```

**Solution 3** : Forcer le reload de l'app
```bash
flutter clean
flutter pub get
flutter run
```

### Les anciens utilisateurs ne sont pas trouvés

**C'est normal** ✅ - Le fallback client-side cherche dans les autres champs.

Vérifier que le texte saisi est contenu dans :
- `firstName`
- `lastName`
- `username`
- `displayName`
- `phone`

**Optionnel** : Exécuter le script de migration pour ajouter les keywords

---

## 🔐 Sécurité & Performance

### Firestore Rules (déjà ok)
Les utilisateurs ne peuvent lire que leurs propres données + la liste complète des utilisateurs pour la recherche.

### Index Firestore (optionnel mais recommandé)

Pour optimiser la recherche sur `keywords`, créer un index Composite :

```
Collection: users
Fields indexed:
  - keywords (Arrays)
  - status (Ascending) - si vous en avez
```

> ℹ️ Firestore créera automatiquement l'index quand tu feras la première requête `.where('keywords', arrayContains: ...)`

---

## 📊 Métriques à surveiller

Après le déploiement, monitorer :

- **Nombre de recherches réussies** : Devrait augmenter
- **Temps de réponse** : Devrait être < 500ms
- **Erreurs de recherche** : Devrait être proche de 0%
- **Adoption** : Combien d'utilisateurs utilisent la recherche ?

---

## 📝 Changelog

```
Version 1.X.X
- ✨ Nouvelle recherche d'utilisateurs robuste
- 🔧 Ajout du champ keywords pour les nouveaux comptes
- 🎯 Fallback client-side pour les anciens comptes
- 📈 Meilleure performance de recherche
- 🐛 Correction: recherche vide n'affichait rien
```

---

## 🆘 Support

Si tu rencontres des problèmes :

1. **Vérifier les logs** : `flutter logs`
2. **Vérifier Firebase Console** : https://console.firebase.google.com
3. **Consulter** `SEARCH_USER_FIX.md` pour plus de détails techniques
4. **Consulter** `MODIFICATIONS_RECHERCHE.md` pour les changements exacts

