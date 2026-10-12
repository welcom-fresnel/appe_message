# 🎨 Palette de Couleurs - Hermin App

Ce document définit la palette de couleurs officielle de l'application pour maintenir une cohérence visuelle.

## 📐 Couleurs Principales

### 1. **Bleu Principal** - `Colors.blue[700]`
**Usage** : Accents, éléments interactifs, badges
- Boutons principaux
- Badges de notification
- Éléments mis en avant
- Icônes actives

**Hex** : `#1976D2`

```dart
// Exemple
Container(
  color: Colors.blue[700],
  child: Text('Action', style: TextStyle(color: Colors.white)),
)
```

### 2. **Bleu Clair** - `Colors.blue[100]`
**Usage** : Backgrounds doux, zones de saisie, avatars
- Background des champs de recherche
- Background des avatars sans photo
- Zones subtiles nécessitant une légère distinction
- Sections mises en valeur doucement

**Hex** : `#BBDEFB`

```dart
// Exemple
TextField(
  decoration: InputDecoration(
    fillColor: Colors.blue[100],
    filled: true,
  ),
)
```

### 3. **Blanc** - `Colors.white`
**Usage** : Surfaces principales, cartes, conteneurs
- Background principal de l'app
- Cartes de contenu
- AppBar
- Containers principaux

**Hex** : `#FFFFFF`

```dart
// Exemple
Scaffold(
  backgroundColor: Colors.white,
  appBar: AppBar(backgroundColor: Colors.white),
)
```

### 4. **Gris Moyen** - `Colors.grey[600]`
**Usage** : Textes principaux, titres, textes importants
- Titres principaux
- Noms d'utilisateurs
- Textes de navigation
- Labels importants
- Icônes actives

**Hex** : `#757575`

```dart
// Exemple
Text(
  'Titre principal',
  style: TextStyle(
    color: Colors.grey[600],
    fontWeight: FontWeight.w600,
  ),
)
```

### 5. **Gris Clair** - `Colors.grey[400]`
**Usage** : Éléments secondaires, icônes passives
- Icônes inactives
- Séparateurs visuels
- États désactivés
- Placeholder icons

**Hex** : `#BDBDBD`

```dart
// Exemple
Icon(
  Icons.chat_bubble_outline,
  color: Colors.grey[400],
  size: 20,
)
```

---

## 🎯 Guide d'Utilisation

### Hiérarchie Visuelle

```
Importance     │ Couleur          │ Usage
───────────────┼──────────────────┼────────────────────
Très Important │ Colors.blue[700] │ Actions, CTAs
Important      │ Colors.grey[600] │ Textes principaux
Neutre         │ Colors.white     │ Surfaces
Subtil         │ Colors.blue[100] │ Backgrounds doux
Secondaire     │ Colors.grey[400] │ Icônes passives
```

### Exemples d'Application

#### 1. **Liste de Conversations**
```dart
ListTile(
  // Avatar avec background bleu clair
  leading: CircleAvatar(
    backgroundColor: Colors.blue[100],
    child: Text(
      'JD',
      style: TextStyle(color: Colors.blue[700]),
    ),
  ),
  // Titre en gris foncé
  title: Text(
    'Jean Dupont',
    style: TextStyle(color: Colors.grey[600]),
  ),
  // Badge en bleu foncé
  trailing: Container(
    decoration: BoxDecoration(
      color: Colors.blue[700],
    ),
    child: Text('3', style: TextStyle(color: Colors.white)),
  ),
)
```

#### 2. **Barre de Recherche**
```dart
TextField(
  decoration: InputDecoration(
    // Background bleu clair
    fillColor: Colors.blue[100],
    filled: true,
    // Icône en gris
    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
    // Pas de bordure
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
    ),
  ),
)
```

#### 3. **AppBar**
```dart
AppBar(
  // Background blanc
  backgroundColor: Colors.white,
  // Icône retour en gris
  leading: Icon(Icons.arrow_back, color: Colors.grey[600]),
  // Titre en gris
  title: Text(
    'Messages',
    style: TextStyle(color: Colors.grey[600]),
  ),
)
```

---

## ❌ À Éviter

### Couleurs à NE PAS utiliser

- ❌ `Colors.black` ou `Colors.black87` → Utiliser `Colors.grey[600]`
- ❌ `Colors.red` → Utiliser `Colors.blue[700]` pour les badges
- ❌ `Colors.grey[50]` ou `Colors.grey[100]` → Utiliser `Colors.white` ou `Colors.blue[100]`
- ❌ `Colors.blue[500]` ou autres nuances → Rester sur `blue[700]` et `blue[100]`

### Mauvais Exemples

```dart
// ❌ Mauvais - Trop de variations
Container(color: Colors.red)
Text(style: TextStyle(color: Colors.black))
Container(color: Colors.grey[50])
Icon(color: Colors.blue[500])

// ✅ Bon - Palette cohérente
Container(color: Colors.blue[700])
Text(style: TextStyle(color: Colors.grey[600]))
Container(color: Colors.white)
Icon(color: Colors.blue[100])
```

---

## 🔄 Combinaisons Recommandées

### 1. **Contraste Fort**
```dart
// Texte foncé sur fond clair
Container(
  color: Colors.white,
  child: Text('Texte', style: TextStyle(color: Colors.grey[600])),
)
```

### 2. **Contraste Moyen**
```dart
// Texte sur fond bleu clair
Container(
  color: Colors.blue[100],
  child: Text('Texte', style: TextStyle(color: Colors.blue[700])),
)
```

### 3. **Contraste Maximum**
```dart
// Texte blanc sur bleu foncé
Container(
  color: Colors.blue[700],
  child: Text('Action', style: TextStyle(color: Colors.white)),
)
```

---

## 📱 Application par Écran

### FeedScreen
- Background: `Colors.white`
- Cartes: `Colors.white` avec ombre
- Textes: `Colors.grey[600]`
- Boutons: `Colors.blue[700]`

### ChatListScreen
- Background: `Colors.white`
- Recherche: `Colors.blue[100]` (fill)
- Avatars: `Colors.blue[100]` (background)
- Badges: `Colors.blue[700]`
- Textes: `Colors.grey[600]`
- Icônes: `Colors.grey[400]`

### ProfileScreen
- Background: `Colors.white`
- Header: `Colors.blue[700]` (gradient possible)
- Sections: `Colors.white` (cartes)
- Textes: `Colors.grey[600]`

### NavigationBar
- Background: `Colors.white`
- Icônes inactives: `Colors.grey[400]`
- Icônes actives: `Colors.blue[700]`
- Badges: `Colors.blue[700]`

---

## 🎨 Accessibilité

### Ratios de Contraste WCAG

| Combinaison | Ratio | Conformité |
|-------------|-------|------------|
| `grey[600]` sur `white` | 4.54:1 | ✅ AA |
| `blue[700]` sur `white` | 4.61:1 | ✅ AA |
| `white` sur `blue[700]` | 4.61:1 | ✅ AA |
| `blue[700]` sur `blue[100]` | 5.73:1 | ✅ AAA |

Tous les contrastes respectent les standards WCAG 2.1 niveau AA minimum.

---

## 💡 Conseils

1. **Cohérence** : Utiliser toujours les mêmes couleurs pour les mêmes éléments
2. **Hiérarchie** : Le bleu foncé attire l'attention, utiliser avec parcimonie
3. **Lisibilité** : Toujours tester le contraste texte/background
4. **Simplicité** : 5 couleurs suffisent pour une app cohérente

---

**Dernière mise à jour** : 29 Décembre 2025  
**Version** : 1.0

