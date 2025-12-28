const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cloudinary = require('cloudinary').v2;
admin.initializeApp();

// Configure Cloudinary using functions config. Set with:
// firebase functions:config:set cloudinary.cloud_name="..." cloudinary.api_key="..." cloudinary.api_secret="..."
if (functions.config && functions.config().cloudinary) {
  const cfg = functions.config().cloudinary;
  cloudinary.config({
    cloud_name: cfg.cloud_name,
    api_key: cfg.api_key,
    api_secret: cfg.api_secret,
  });
}

// Envoie une notification FCM lors de la création d'un post avec image
exports.onImagePostCreated = functions.firestore
    .document("posts/{postId}")
    .onCreate(async (snap, context) => {
      try {
        const data = snap.data();
        if (!data) return;
        // Vérifie la présence d'une image
        const hasImage = Array.isArray(data.mediaUrls) ? data.mediaUrls.length > 0 : !!data.imageUrl;
        if (!hasImage) return;

        const title = "Administration";
        const body = "Nouvelle image publiée !";
        // Envoie à tous les utilisateurs abonnés au topic général
        await admin.messaging().send({
          topic: "all_users",
          notification: { title, body },
          data: {
            type: "image",
            postId: String(context.params.postId),
          },
          android: {
            priority: "high",
            notification: { channelId: "hermin_default" },
          },
        });
      } catch (e) {
        console.error("onImagePostCreated error", e);
      }
    });

exports.syncCommentsCount = functions.firestore
    .document("posts/{postId}")
    .onWrite(async (change) => {
      const after = change.after.exists ? change.after.data() : null;
      if (!after) return;
      const comments = Array.isArray(after.comments) ? after.comments : [];
      const count = comments.length;
      const existing = (after.commentsCount != null) ? after.commentsCount : 0;
      if (existing !== count) {
        await change.after.ref.update({commentsCount: count});
      }
    });

// Send FCM notification on new message
exports.onMessageCreated = functions.firestore
    .document("messages/{messageId}")
    .onCreate(async (snap, context) => {
      try {
        const data = snap.data();
        if (!data) return;
        const categories = Array.isArray(data.categories) ? data.categories : [];
        if (categories.length === 0) return;

        const type = data.type || "text";
        const title = data.authorName || "Administration";
        const body = (type === "text") ?
        (data.text || "Nouvelle annonce") :
        "Nouvelle annonce vocale";

        const messaging = admin.messaging();
        const sends = categories.map((c) => {
          const topic = `category_${c}`;
          return messaging.send({
            topic,
            notification: {title, body},
            data: {
              type: String(type),
              messageId: String(context.params.messageId),
            },
            android: {
              priority: "high",
              notification: {channelId: "hermin_default"},
            },
          }).catch(() => undefined);
        });
        await Promise.all(sends);
      } catch (e) {
        console.error("onMessageCreated error", e);
      }
    });

// Notify admins when a user sends a message to 'reception' collection
exports.onReceptionCreated = functions.firestore
    .document('reception/{receptionId}')
    .onCreate(async (snap, context) => {
      try {
        const data = snap.data();
        if (!data) return;

        const title = data.senderName || 'Nouveau message';
        const body = (data.text && data.text.length > 0) ? (data.text.slice(0, 120)) : 'Nouveau message reçu';

        // Send notification to admins topic (admins should be subscribed server-side or via client)
        await admin.messaging().send({
          topic: 'admins',
          notification: { title, body },
          data: {
            type: 'reception',
            receptionId: String(context.params.receptionId),
          },
          android: {
            priority: 'high',
            notification: { channelId: 'hermin_default' },
          },
        });
      } catch (e) {
        console.error('onReceptionCreated error', e);
      }
    });

// Notify participants (except sender) when a new private message is created
exports.onConversationMessageCreated = functions.firestore
    .document('conversations/{conversationId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
      try {
        const data = snap.data();
        if (!data) return;

        const conversationId = context.params.conversationId;
        const senderId = data.senderId || '';
        const text = data.text || '';
        const type = data.type || 'text';

        // Load conversation to get participants
        const convSnap = await admin.firestore().collection('conversations').doc(conversationId).get();
        if (!convSnap.exists) return;
        const conv = convSnap.data() || {};
        const participants = Array.isArray(conv.participants) ? conv.participants : [];

        const title = conv.title || 'Nouveau message';
        const body = type === 'text' ? (text.length > 120 ? text.slice(0, 120) + '...' : text) : '📷 Nouvelle image';

        const messaging = admin.messaging();

        // Send to each participant topic 'user_<uid>' except the sender
        const sends = participants
            .filter(p => p && p !== senderId)
            .map(uid => {
              const topic = `user_${uid}`;
              return messaging.send({
                topic,
                notification: { title, body },
                data: {
                  type: 'conversation_message',
                  conversationId: String(conversationId),
                  messageId: String(context.params.messageId),
                },
                android: {
                  priority: 'high',
                  notification: { channelId: 'hermin_default' },
                },
              }).catch((err) => {
                console.error('send to topic error', topic, err);
                return null;
              });
            });

        await Promise.all(sends);
      } catch (e) {
        console.error('onConversationMessageCreated error', e);
      }
    });

  // Callable function to delete Cloudinary images by public id(s).
  exports.deleteCloudinaryImages = functions.https.onCall(async (data, context) => {
    // Only authenticated admins may call
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const uid = context.auth.uid;
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    const user = userDoc.exists ? userDoc.data() : null;
    if (!user || user.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Admin only');
    }

    const publicIds = Array.isArray(data.publicIds) ? data.publicIds : [];
    if (publicIds.length === 0) {
      return {ok: true, message: 'no_public_ids'};
    }

    const results = [];
    for (const pid of publicIds) {
      try {
        // resource_type auto for images
        const res = await cloudinary.uploader.destroy(pid, {invalidate: true});
        results.push({publicId: pid, result: res});
      } catch (e) {
        console.error('cloudinary destroy error', pid, e);
        results.push({publicId: pid, error: String(e)});
      }
    }

    return {ok: true, results};
  });

exports.createUserByAdmin = functions.https.onCall(async (data, context) => {
  // 1. Vérifier que l'appelant est authentifié et admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Vous devez être connecté pour effectuer cette action.'
    );
  }

  // Vérifier que l'utilisateur est admin
  const adminSnapshot = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (!adminSnapshot.exists || adminSnapshot.data().role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Droits administrateur requis.'
    );
  }

  // 2. Valider les données d'entrée
  const requiredFields = ['email', 'password', 'firstName', 'lastName', 'phone', 'category'];
  const missingFields = requiredFields.filter(field => !data[field]);
  
  if (missingFields.length > 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Champs manquants : ${missingFields.join(', ')}`
    );
  }

  const { email, password, firstName, lastName, phone, category } = data;
  const displayName = `${firstName} ${lastName}`.trim();

  try {
    // 3. Créer l'utilisateur dans Firebase Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
      emailVerified: false, // L'utilisateur devra vérifier son email
      disabled: false
    });

    // 4. Préparer les données pour Firestore
    const userData = {
      uid: userRecord.uid,
      email,
      firstName,
      lastName,
      displayName,
      phone: phone || null,
      category,
      role: category, // 'parent', 'eleve', 'enseignant'
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Champs spécifiques par catégorie
      ...(category === 'parent' && {
        parentOf: data.parentOf || null,
        studentClass: data.studentClass || null
      }),
      ...(category === 'enseignant' && {
        subject: data.subject || null,
        classes: data.classes || []
      })
    };

    // 5. Créer le document dans Firestore
    await admin.firestore()
      .collection('users')
      .doc(userRecord.uid)
      .set(userData, { merge: true });

    // 6. Envoyer un email de réinitialisation de mot de passe
    await admin.auth().generatePasswordResetLink(email)
      .then((link) => {
        // Ici tu pourrais envoyer un email personnalisé avec le lien
        console.log(`Lien de réinitialisation pour ${email}: ${link}`);
        // Exemple avec un service d'email comme Nodemailer ou SendGrid
        // await sendCustomEmail(email, link);
      });

    return { 
      success: true, 
      uid: userRecord.uid,
      email: userRecord.email,
      displayName: userRecord.displayName
    };

  } catch (error) {
    console.error('Erreur création utilisateur:', error);
    
    // En cas d'erreur, supprimer l'utilisateur Auth si création partielle
    if (error.uid) {
      try {
        await admin.auth().deleteUser(error.uid);
      } catch (deleteError) {
        console.error('Erreur nettoyage utilisateur partiel:', deleteError);
      }
    }
    
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Une erreur est survenue lors de la création du compte.'
    );
  }
});
