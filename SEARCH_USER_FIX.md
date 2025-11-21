# 🔧 Correctif - Recherche d'utilisateurs individuelle

## 🐛 Problème identifié

Lors de l'envoi d'un message individuel dans l'application admin, la recherche d'utilisateurs ne retournait aucun résultat, même si l'utilisateur existait dans Firebase.

### Cause racine

1. **Champ `keywords` manquant** : La recherche utilisait un champ `keywords` qui n'existait pas dans les documents des utilisateurs
2. **Pas de génération de keywords** : Au moment de la création du compte, aucun champ `keywords` n'était créé

### Fichiers affectés

- `hermin/lib/screens/auth_screen.dart` - Création de compte
- `hermine_admin/lib/screens/compose_message_screen.dart` - Recherche d'utilisateurs

---

## ✅ Solution implémentée

### 1️⃣ Génération des keywords lors de l'inscription (`auth_screen.dart`)

Lors de la création d'un nouveau compte, on génère maintenant un champ `keywords` qui contient :
- Le prénom (et tous ses préfixes) en minuscules
- Le nom (et tous ses préfixes) en minuscules  
- Le téléphone (si fourni)

**Exemple** :
```dart
// Si prénom = "Jean" et nom = "Dupont"
keywords = [
  "jean", "j", "je", "jea",  // prénom et ses préfixes
  "dupont", "d", "du", "dup", "dupo", "dupon"  // nom et ses préfixes
]
```

Cela permet une **recherche par préfixe très rapide** grâce aux indexes Firestore.

### 2️⃣ Recherche robuste avec fallback (`compose_message_screen.dart`)

La recherche utilise maintenant une **stratégie à deux niveaux** :

**Niveau 1 - Recherche optimisée** :
```dart
// Essayer d'abord avec l'index keywords (rapide)
.where('keywords', arrayContains: query.toLowerCase())
```

**Niveau 2 - Fallback client-side** :
Si l'index n'existe pas (anciens utilisateurs), on :
1. Récupère jusqu'à 100 utilisateurs
2. Filtre localement en cherchant dans :
   - `firstName`
   - `lastName`
   - `username`
   - `displayName`
   - `phone`

Cela garantit que **même les anciens utilisateurs** sans le champ `keywords` peuvent être trouvés.

---

## 📋 Checklist d'action

Pour que la correction fonctionne complètement :

- [ ] **Pour les NOUVEAUX utilisateurs** : Automatiquement, le champ `keywords` est créé
- [ ] **Pour les ANCIENS utilisateurs** : La recherche utilise le fallback (client-side filtering)
- [ ] **Optionnel - Migration** : Exécuter un script Cloud Function pour ajouter `keywords` aux anciens documents

### Script de migration (Cloud Function) - Optionnel

```javascript
// Deploy avec: firebase deploy --only functions:migrateKeywords
exports.migrateKeywords = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const usersRef = db.collection('users');
  
  const snapshot = await usersRef.get();
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const keywords = new Set();
    
    // Générer keywords pour prénom
    if (data.firstName) {
      const firstName = data.firstName.toLowerCase();
      keywords.add(firstName);
      for (let i = 1; i <= firstName.length; i++) {
        keywords.add(firstName.substring(0, i));
      }
    }
    
    // Générer keywords pour nom
    if (data.lastName) {
      const lastName = data.lastName.toLowerCase();
      keywords.add(lastName);
      for (let i = 1; i <= lastName.length; i++) {
        keywords.add(lastName.substring(0, i));
      }
    }
    
    // Ajouter téléphone
    if (data.phone) {
      keywords.add(data.phone);
    }
    
    await doc.ref.update({
      keywords: Array.from(keywords)
    });
  }
  
  res.send('Migration complétée');
});
```

---

## 🧪 Tests

Tester la recherche avec ces scénarios :

✅ Taper le début du prénom → Résultats
✅ Taper le début du nom → Résultats
✅ Taper un numéro de téléphone → Résultats
✅ Moins de 2 caractères → Message "Tapez au moins 2 caractères…"
✅ Aucune correspondance → Message "Aucun utilisateur trouvé"

---

## 📊 Comparaison

### Avant
```
Utilisateur tape: "Jean"
→ Aucun résultat ❌
```

### Après
```
Utilisateur tape: "Jea"
→ Affiche tous les Jean ✅

Utilisateur tape: "Dup"
→ Affiche tous les Dupont ✅

Utilisateur tape: "1234567"
→ Affiche le contact avec ce téléphone ✅
```

---

## 🚀 Prochaines améliorations possibles

1. **Recherche phonétique** - Utiliser une library comme `metaphone` pour les homophones
2. **Recherche Firestore full-text** - Utiliser une extension Elasticsearch
3. **Debouncing** - Éviter les recherches trop fréquentes
4. **Cache local** - Cacher les résultats précédents

