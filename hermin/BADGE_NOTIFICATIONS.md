# 🔔 Système de Badge de Notifications

Ce document explique comment fonctionne le badge de notifications sur l'icône Messages.

## 📊 Fonctionnement

### 1. Badge sur l'icône Messages

Le badge affiche le **nombre de conversations non lues** en temps réel.

```dart
// Dans home_shell.dart
NavigationDestination(
  icon: _buildBadgedIcon(
    icon: Icons.chat_bubble_outline,
    count: unreadCount,  // ← Nombre affiché
  ),
  label: 'Messages',
)
```

### 2. Calcul des conversations non lues

Une conversation est considérée comme **non lue** si :

1. ✅ Elle a été mise à jour (`lastUpdated`)
2. ✅ L'utilisateur ne l'a jamais lue OU l'a lue avant la dernière mise à jour
3. ✅ Le dernier message n'a **pas** été envoyé par l'utilisateur actuel

```dart
// Logique dans home_shell.dart
Stream<int> _getUnreadConversationsCount() {
  // Récupère toutes les conversations de l'utilisateur
  // Compare lastUpdated avec conversationsLastRead[conversationId]
  // Vérifie que lastMessageSenderId != userId actuel
  // Retourne le nombre de conversations non lues
}
```

### 3. Structure Firestore

#### Collection `conversations`

```json
{
  "participants": ["uid1", "uid2"],
  "lastMessage": "Salut !",
  "lastMessageSenderId": "uid2",  // ← ID du dernier expéditeur
  "lastUpdated": Timestamp,
  "createdAt": Timestamp
}
```

#### Collection `users` (document utilisateur)

```json
{
  "conversationsLastRead": {
    "conversationId1": Timestamp,  // ← Dernière lecture
    "conversationId2": Timestamp,
    "conversationId3": Timestamp
  }
}
```

### 4. Marquage comme lu

Quand l'utilisateur ouvre une conversation :

```dart
// Dans chat_screen.dart - initState()
await ConversationService.instance.markConversationAsRead(
  widget.conversationId,
  currentUserId,
);
```

Cela met à jour :
```json
{
  "users/currentUserId": {
    "conversationsLastRead": {
      "conversationId": Timestamp.now()  // ← Mis à jour
    }
  }
}
```

## 🎨 Personnalisation du Badge

### Changer la couleur

```dart
Widget _buildBadgedIcon({
  required IconData icon,
  required int count,
}) {
  return Badge(
    label: Text('$count'),
    isLabelVisible: count > 0,
    backgroundColor: Colors.red,  // ← Couleur personnalisée
    textColor: Colors.white,
    child: Icon(icon),
  );
}
```

### Limiter l'affichage (ex: 99+)

```dart
Widget _buildBadgedIcon({
  required IconData icon,
  required int count,
}) {
  final displayCount = count > 99 ? '99+' : '$count';
  
  return Badge(
    label: Text(displayCount),
    isLabelVisible: count > 0,
    child: Icon(icon),
  );
}
```

## 🔄 Flux de données

```
1. Nouveau message envoyé
   ↓
2. ConversationService.sendMessage()
   ↓
3. Mise à jour de la conversation :
   - lastMessage
   - lastMessageSenderId ← Important !
   - lastUpdated
   ↓
4. Stream dans home_shell.dart détecte le changement
   ↓
5. Compare avec conversationsLastRead[conversationId]
   ↓
6. Incrémente le compteur si non lu
   ↓
7. Badge mis à jour automatiquement
   ↓
8. Utilisateur ouvre la conversation
   ↓
9. markConversationAsRead() appelé
   ↓
10. conversationsLastRead mis à jour
   ↓
11. Badge décrémente automatiquement
```

## ⚡ Optimisations possibles

### 1. Ajouter un champ `unreadCount` direct

Au lieu de calculer à chaque fois, stocker le nombre dans la conversation :

```json
{
  "conversations/conversationId": {
    "unreadBy": {
      "uid1": 3,  // 3 messages non lus par uid1
      "uid2": 0   // 0 messages non lus par uid2
    }
  }
}
```

### 2. Utiliser Cloud Functions

Mettre à jour automatiquement `unreadCount` avec une Cloud Function :

```javascript
exports.updateUnreadCount = functions.firestore
  .document('conversations/{convId}/messages/{msgId}')
  .onCreate((snap, context) => {
    // Incrémenter unreadCount pour tous les participants
    // sauf l'expéditeur
  });
```

### 3. Cache local

Stocker le dernier compteur localement pour affichage instantané :

```dart
// Utiliser SharedPreferences
final prefs = await SharedPreferences.getInstance();
final cachedCount = prefs.getInt('unreadMessagesCount') ?? 0;
```

## 🐛 Debugging

### Vérifier les timestamps

```dart
// Dans Firestore Console
conversations/conversationId
  lastUpdated: Timestamp

users/userId
  conversationsLastRead:
    conversationId: Timestamp
```

### Logger les calculs

```dart
print('Conversation $conversationId:');
print('  lastUpdated: $lastUpdated');
print('  lastRead: $lastReadTimestamp');
print('  isUnread: ${lastUpdated.isAfter(lastReadTimestamp)}');
```

## 📝 Notes

- Le badge se met à jour **en temps réel** grâce aux Streams Firestore
- Pas besoin de rafraîchir manuellement
- Fonctionne même si l'app est en arrière-plan (avec FCM)
- Compatible avec le système de notifications push

---

**Créé le** : 29 Décembre 2025  
**Dernière mise à jour** : 29 Décembre 2025

