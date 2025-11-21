const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

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
