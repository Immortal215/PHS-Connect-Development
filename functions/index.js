const { onValueCreated, onValueWritten } = require("firebase-functions/v2/database");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Notification rules (stored under each user: /users/{uid}/...)
 *
 * user.chatNotifStyles: { [chatID]: "all" | "thread" | "none" | "mentions" }
 * user.mutedThreadsByChat: { [chatID]: [threadName, ...] }   // thread NAMES exactly as stored
 *
 * Precedence:
 * - none: never notify
 * - mentions: only notify if isMention == true (mention detection not implemented here)
 * - all: notify always
 * - thread: notify unless threadName is in mutedThreadsByChat[chatID]
 */

exports.sendChatNotification = onValueCreated(
  "/chats/{chatID}/messages/{messageID}",
  async (event) => {
    const message = event.data.val();
    const chatID = event.params.chatID;
    const messageID = event.params.messageID;

    const senderUID = message.sender;
    const messageText = message.message || "";
    const threadName = message.threadName || "general";

    const isMention = false;

    try {
      const chatSnap = await admin.database().ref(`/chats/${chatID}`).once("value");
      const chatData = chatSnap.val();
      if (!chatData || !chatData.clubID) return;

      const clubID = chatData.clubID;

      const clubSnap = await admin.database().ref(`/clubs/${clubID}`).once("value");
      const clubData = clubSnap.val();
      if (!clubData) return;

      const clubMembersEmails = clubData.members || [];
      const clubLeadersEmails = clubData.leaders || [];
      const clubName = clubData.name || "New Message";

      const usersSnap = await admin.database().ref("/users").once("value");
      const allUsers = usersSnap.val() || {};

      const senderName = allUsers?.[senderUID]?.userName || "Someone";
      const tokens = [];

      for (const uid in allUsers) {
        if (uid === senderUID) continue;

        const user = allUsers[uid];
        if (!user) continue;
        if (!user.fcmToken) continue;

        const email = user.userEmail;
        const isMember = clubMembersEmails.includes(email);
        const isLeader = clubLeadersEmails.includes(email);
        if (!(isMember || isLeader)) continue;

        const style =
          (user.chatNotifStyles && user.chatNotifStyles[chatID]) || "all";

        if (style === "none") continue;

        if (style === "mentions") {
          if (!isMention) continue;
        }

        if (style === "thread") {
          const muted =
            (user.mutedThreadsByChat &&
              user.mutedThreadsByChat[chatID] &&
              Array.isArray(user.mutedThreadsByChat[chatID]) &&
              user.mutedThreadsByChat[chatID].includes(threadName)) || false;

          if (muted) continue;
        }

        // style === "all" falls through, notify
        tokens.push(user.fcmToken);
      }

      if (tokens.length === 0) return;

      const preview = messageText.length > 0 ? messageText.slice(0, 80) : "(attachment)";

      return admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: `${senderName} • ${clubName}`,
          body: threadName === "general" ? preview : `[${threadName}] ${preview}`,
        },
        data: {
          type: "message",
          chatID,
          messageID,
          threadName,
          senderUID,
          clubID,
          clubName,
          senderName,
          preview,
        },
      });
    } catch (err) {
      console.error("Error sending push notification:", err);
    }
  }
);

exports.sendReactionNotification = onValueWritten(
  "/chats/{chatID}/messages/{messageID}/reactions/{emoji}",
  async (event) => {
    const { chatID, messageID, emoji } = event.params;

    const beforeArr = event.data.before.exists() ? (event.data.before.val() || []) : [];
    const afterArr = event.data.after.exists() ? (event.data.after.val() || []) : [];

    if (!Array.isArray(afterArr)) return;
    const beforeLen = Array.isArray(beforeArr) ? beforeArr.length : 0;
    if (afterArr.length <= beforeLen) return;

    const beforeSet = new Set(Array.isArray(beforeArr) ? beforeArr : []);
    const reactorUID = afterArr.find((u) => !beforeSet.has(u));
    if (!reactorUID) return;

    try {
      const senderSnap = await admin.database().ref(`/chats/${chatID}/messages/${messageID}/sender`).once("value");
      const messageSenderUID = senderSnap.val();
      if (!messageSenderUID) return;

      // Don't notify yourself
      if (messageSenderUID === reactorUID) return;

      const receiverSnap = await admin.database().ref(`/users/${messageSenderUID}`).once("value");
      const receiver = receiverSnap.val();
      if (!receiver) return;

      const style =
        (receiver.chatNotifStyles && receiver.chatNotifStyles[chatID]) || "all";

      if (style === "none") return;


      if (style === "mentions") return;

      const token = receiver.fcmToken;
      if (!token) return;

      const reactorNameSnap = await admin.database().ref(`/users/${reactorUID}/userName`).once("value");
      const reactorName = reactorNameSnap.val() || "Someone";

      const clubIDSnap = await admin.database().ref(`/chats/${chatID}/clubID`).once("value");
      const clubID = clubIDSnap.val() || "";

      let clubName = "Reaction";
      if (clubID) {
        const clubNameSnap = await admin.database().ref(`/clubs/${clubID}/name`).once("value");
        clubName = clubNameSnap.val() || "Reaction";
      }

      return admin.messaging().send({
        token,
        notification: {
          title: `${reactorName} • ${clubName}`,
          body: `reacted ${emoji}`,
        },
        data: {
          type: "reaction",
          chatID,
          messageID,
          clubID: clubID || "",
          clubName,
          reactorUID,
          reactorName,
          emoji,
        },
      });
    } catch (err) {
      console.error("Error sending reaction notification:", err);
    }
  }
);
