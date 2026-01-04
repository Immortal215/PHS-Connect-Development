const { onValueCreated, onValueWritten } = require("firebase-functions/v2/database");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendChatNotification = onValueCreated(
  "/chats/{chatID}/messages/{messageID}",
  async (event) => {
    const message = event.data.val();
    const chatID = event.params.chatID;
    const messageID = event.params.messageID;

    const senderUID = message.sender;
    const messageText = message.message || "";
    const threadName = message.threadName || "general";

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
      const allUsers = usersSnap.val();

      const senderName = allUsers?.[senderUID]?.userName || "Someone";
      const tokens = [];

      for (const uid in allUsers) {
        if (uid === senderUID) continue;
        const user = allUsers[uid];
        if (!user) continue;

        const email = user.userEmail;
        const isMember = clubMembersEmails.includes(email);
        const isLeader = clubLeadersEmails.includes(email);

        if ((isMember || isLeader) && user.fcmToken) tokens.push(user.fcmToken);
      }

      if (tokens.length === 0) return;

      const preview = messageText.length > 0 ? messageText.slice(0, 80) : "(attachment)";

      return admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: `${senderName} • ${clubName}`,
          body: threadName === "general" ? preview : `[${threadName}] ${preview}`
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
          preview
        }
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

    // Only notify when a reaction was added (array grew)
    if (!Array.isArray(afterArr)) return;
    if (afterArr.length <= (Array.isArray(beforeArr) ? beforeArr.length : 0)) return;

    // Find who got added (best effort)
    const beforeSet = new Set(Array.isArray(beforeArr) ? beforeArr : []);
    const addedUID = afterArr.find((u) => !beforeSet.has(u));
    if (!addedUID) return;

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
      const clubName = clubData.name || "Reaction";

      const usersSnap = await admin.database().ref("/users").once("value");
      const allUsers = usersSnap.val();

      const reactorName = allUsers?.[addedUID]?.userName || "Someone";
      const tokens = [];

      for (const uid in allUsers) {
        if (uid === addedUID) continue;

        const user = allUsers[uid];
        if (!user) continue;

        const email = user.userEmail;
        const isMember = clubMembersEmails.includes(email);
        const isLeader = clubLeadersEmails.includes(email);

        if ((isMember || isLeader) && user.fcmToken) tokens.push(user.fcmToken);
      }

      if (tokens.length === 0) return;

      return admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: `${reactorName} • ${clubName}`,
          body: `reacted ${emoji}`
        },
        data: {
          type: "reaction",
          chatID,
          messageID,
          clubID,
          clubName,
          reactorUID: addedUID,
          reactorName,
          emoji
        }
      });
    } catch (err) {
      console.error("Error sending reaction notification:", err);
    }
  }
);
