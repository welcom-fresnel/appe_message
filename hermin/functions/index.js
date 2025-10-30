const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

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
