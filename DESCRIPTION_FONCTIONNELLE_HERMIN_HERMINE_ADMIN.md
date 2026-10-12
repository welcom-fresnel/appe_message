# Description fonctionnelle (ce que fait l'app)

Date d'observation: 2026-03-26 (Europe/Paris)
Portee: dossiers `d:\app_message\hermin` et `d:\app_message\hermine_admin`.
Source: lecture du code Flutter (principalement `lib/`).

## 1) App mobile `hermin` (cote utilisateurs)

### Objectif general
Application communautaire/etablissement nommee "LEAURRY-FLORIDE" (nom visible dans l'app) permettant aux utilisateurs de:
- se connecter / creer un compte
- consulter et publier des posts (texte + images)
- liker / commenter / signaler des contenus
- recevoir des annonces (texte ou audio) ciblees par categorie
- echanger en messages prives (conversations)
- gerer leur profil (infos perso/pro, preferences)

### Parcours principal
1) **Authentification**
   - Connexion par email/mot de passe.
   - Creation de compte avec prenom/nom/telephone + selection d'une categorie (`parent` ou `eleve`).
   - Enregistrement du profil utilisateur dans Firestore (nom, telephone, categorie, etc.).
   - Reinitialisation du mot de passe par email.

2) **Accueil (navigation bas de page)**
   Onglets:
   - Accueil (fil d'actualite)
   - Messages (conversations)
   - Annonces
   - Profil

3) **Fil d’actualite (posts)**
   - Liste des posts (Firestore `posts`) par ordre chronologique.
   - Recherche locale par texte ou auteur.
   - Creation d’un post avec texte + plusieurs images.
   - Upload des images vers Cloudinary puis stockage des URLs dans Firestore.
   - Interactions:
     - Like / unlike
     - Commentaires (ajout et affichage)
     - Signalement d’un post (reasons predefinis) -> collection `reports`
   - Affichage d’un badge “Nouveau” si post < 24h.
   - Visualisation plein ecran des images.

4) **Annonces ciblees**
   - Affiche les messages de la collection `messages` filtres par la **categorie** du profil utilisateur.
   - Annonces texte ou audio.
   - Lecture audio integree (player + barre de progression).
   - Son de cloche lorsqu’une nouvelle annonce arrive.
   - Barre de recherche interne + chips categories (UI, filtrage basic).

5) **Messagerie privee**
   - Liste des conversations (collection `conversations`).
   - Indicateur de non-lu base sur `lastUpdated` vs `lastRead`.
   - Creation de conversation:
     - Contact admin (conversation avec participant `admin`)
     - Nouveau chat avec un utilisateur (selection dans la liste des users).
   - Envoi de messages texte et d’images (upload via service de conversation).

6) **Profil utilisateur**
   - Affichage et edition de:
     - Nom affiche / role / categorie
     - Resume professionnel, preferences, contacts
     - Liste des publications personnelles + suppression
     - Parametres de securite (2FA flag), appareils connectes (UI)
   - Mise a jour du profil en base (Firestore `users`).
   - Reinitialisation du mot de passe par email.

### Donnees/Services cles
- **Firebase Auth** pour l’authentification.
- **Firestore** pour posts, annonces, conversations, users, reports.
- **Cloudinary** pour upload d’images (posts) et gestion d’URLs.
- **Notifications**: badge + hook sur notifications recues.


## 2) App admin `hermine_admin`

### Objectif general
Application d’administration permettant de:
- publier des posts (fil d’actualite)
- envoyer des annonces texte/audio aux categories d’utilisateurs
- envoyer des SMS en parallele (optionnel)
- gerer les utilisateurs (creation/edition/suppression)
- consulter stats et historique des messages
- traiter la reception (conversations entrantes)

### Navigation principale (dashboard moderne)
Onglets:
1) **Feed Admin** (posts)
2) **Reception** (conversations avec `admin`)
3) **Composer message**
4) **Gestion utilisateurs**
5) **Stats**

Menu admin (toolbar): actualiser, historique des messages, parametres, deconnexion.

### Fonctions detaillees
1) **Feed Admin**
   - Liste des posts (Firestore `posts`) avec recherche.
   - Creation de posts avec texte + images.
   - Upload Cloudinary + stockage URLs + publicIds.
   - Actions admin: supprimer un post (avec suppression des images Cloudinary via Cloud Function `deleteCloudinaryImages`).
   - Like/comment/report possibles (comme l’app user).

2) **Reception (support/conversations)**
   - Liste des conversations dont participants contiennent `admin`.
   - Affiche le dernier message et l’heure.
   - Acces a un ecran de chat admin pour repondre.

3) **Composer message (annonces)**
   - Envoi d’un message texte ou vocal.
   - Ciblage:
     - par categories (`parent`, `eleve`, `enseignant`)
     - ou par utilisateur individuel (recherche par nom/telephone)
     - ciblage optionnel des parents d’une classe precise
   - Envoi optionnel de SMS (batch) selon opt-in et numero.
   - Enregistrement des envois dans `sent_messages_history`.
   - Messages audio: enregistrement (max 120s), upload Cloudinary, URL stockee dans `messages`.

4) **Gestion utilisateurs**
   - Liste + recherche + filtrage par categorie.
   - Fiche detail utilisateur (tel, email, categorie, etc.).
   - Creation/modification/suppression d’utilisateurs.
   - Creation par endpoint Netlify `/.netlify/functions/create-user` (admin).

5) **Stats**
   - Nombre de messages aujourd’hui / semaine.
   - Repartition des utilisateurs par categorie.
   - Stats par type de message (texte vs vocal).

6) **Parametres**
   - Region (cm/cg/cd/ci/ga).
   - Mapping SIM (MTN/Airtel) pour envoi SMS.
   - URL d’API SMS externe optionnelle.

### Donnees/Services cles
- **Firebase Auth** (connexion admin).
- **Firestore**: users, messages, posts, conversations, sent_messages_history.
- **Cloudinary**: upload audio + images.
- **Netlify function**: creation d’utilisateurs admin.
- **SMS**: envoi via telephony / passerelle optionnelle.


## 3) Synthese rapide
- **`hermin`** = app utilisateur finale: feed + annonces + chat + profil.
- **`hermine_admin`** = app de gestion: posts, diffusion d’annonces texte/audio, SMS, stats, gestion d’utilisateurs, support.

Fin du document.
