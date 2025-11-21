# 📝 Système de Commentaires & Signalement

## ✨ Nouvelles Fonctionnalités

### 1. **Système de Commentaires Style Facebook**
- ✅ Clic sur le bouton "Commentaires" ouvre une modal avec tous les commentaires
- ✅ Affichage en temps réel des commentaires avec avatars utilisateurs
- ✅ Temps relatif (il y a 2m, il y a 1h, etc.)
- ✅ Zone de saisie en bas de la modal pour ajouter un commentaire
- ✅ Suppression de ses propres commentaires (menu popup)
- ✅ Affichage des 2 premiers commentaires dans le feed avec lien "Voir les X commentaires"

### 2. **Bouton Signaler un Mauvais Contenu**
Nouvelles raisons de signalement:
- 🚩 Contenu offensant
- 🚩 Spam
- 🚩 Contenu violent
- 🚩 Partage de données privées
- 🚩 Autre

**Flux utilisateur:**
1. Clic sur l'icône drapeau ("Signaler")
2. Dialog avec 5 raisons de signalement
3. Clic sur une raison → enregistrement du signalement
4. Message de confirmation: "✅ Merci de votre signalement..."

**Enregistrement:**
```firestore
collection: "reports"
{
  postId: "post_id",
  reportedBy: "user_uid",
  reason: "Contenu offensant",
  createdAt: timestamp,
  status: "pending"
}
```

## 🎨 UI Améliorations

### Boutons d'Action (Like, Commentaire, Signaler)
- Design type Facebook avec 3 boutons côte à côte
- Icônes cohérentes
- Affichage du nombre (likes/commentaires) ou texte d'action
- Couleur rouge pour les likes actifs

### Modal Commentaires
- Header avec titre "Commentaires" et bouton fermer
- StreamBuilder pour mise à jour en temps réel
- Scrollable si beaucoup de commentaires
- Zone de saisie collante en bas (au-dessus du clavier)
- FloatingActionButton "Envoyer" stylisé

### Card Commentaire
- Petit avatar (18px) avec initiales
- Nom utilisateur en gras
- Temps relatif gris
- Texte du commentaire dans une bulle grise (style WhatsApp)
- Menu (3 points) pour supprimer si auteur

## 🔐 Règles Firestore Mises à Jour

```firestore
// Collection: reports
match /reports/{reportId} {
  // Création: tout utilisateur connecté
  allow create: if isSignedIn()
    && request.resource.data.reportedBy == request.auth.uid
    
  // Lecture: admin seulement
  allow read: if isAdmin();
  
  // Mise à jour: admin pour changer le status
  allow update: if isAdmin()
    && changedKeys().hasOnly(['status']);
    
  // Suppression: admin seulement
  allow delete: if isAdmin();
}
```

## 📱 Utilisation

### Pour Commenter:
1. Ouvrir un post
2. Clic sur le bouton "Commentaires" (icône bulle) ou "Voir les X commentaires"
3. Modal s'affiche avec tous les commentaires
4. Écrire dans la zone de saisie en bas
5. Clic sur le bouton d'envoi (papier avion)
6. Commentaire apparaît instantanément

### Pour Supprimer son Commentaire:
1. Dans la modal commentaires, clic sur le menu (3 points) de son commentaire
2. "Supprimer" → confirmé instantanément
3. Score des commentaires décrémente

### Pour Signaler:
1. Ouvrir un post
2. Clic sur l'icône drapeau ("Signaler")
3. Sélectionner une raison
4. Confirmation instantanée avec message

## 🎯 Points Techniques

### Méthodes Implémentées

#### `_showCommentsSheet(context, postId, currentUser)`
- StreamBuilder connecté à la collection posts
- Liste tous les commentaires en temps réel
- Zone de saisie avec validation
- Gestion des erreurs

#### `_deleteComment(postId, index)`
- Récupère la liste des commentaires
- Supprime l'index spécifié
- Met à jour le compteur
- Affiche snackbar de confirmation

#### `_showReportDialog(context, postId)`
- Dialog avec 5 raisons
- Clic sur une raison → `_submitReport()`
- Navigation automatique et message de confirmation

#### `_submitReport(postId, reason)`
- Crée un document dans `reports` collection
- Enregistre: postId, reportedBy, reason, timestamp, status

#### `_getTimeAgo(dateTime)`
- Convertit timestamp en temps relatif
- "À l'instant", "Il y a 2m", "Il y a 1h", etc.

## 📊 Statistiques Firestore

Les commentaires et likes sont stockés directement sur les posts:
```dart
comments: [
  {
    userId: "uid1",
    text: "Super post!",
    createdAt: timestamp
  },
  ...
]
commentsCount: 5
likes: ["uid1", "uid2", ...]
```

## ⚠️ Notes Importantes

1. **Suppression de commentaires:** Affecte immédiatement le compteur
2. **Signalements:** Stockés dans la collection `reports` (admin peut modérer)
3. **Autorisations:** Seul l'auteur du commentaire peut le supprimer
4. **Temps réel:** Tous les changements sont instantanés grâce aux StreamBuilders

## 🚀 Prochaines Étapes (Optionnel)

- [ ] Edit commentaire (pour l'auteur)
- [ ] Likes sur commentaires
- [ ] Réponses imbriquées (nested replies)
- [ ] Notifications quand quelqu'un répond à votre commentaire
- [ ] Dashboard admin pour gérer les signalements

