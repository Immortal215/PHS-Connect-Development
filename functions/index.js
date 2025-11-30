const { onValueCreated } = require("firebase-functions/v2/database");
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

        if ((isMember || isLeader) && user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log("No tokens to notify.");
        return;
      }

      const preview = messageText.length > 0 ? messageText.slice(0, 80) : "(attachment)";

      const payload = {
        notification: {
          title: `${senderName} • ${clubName}`,
          body: threadName === "general"
            ? preview
            : `[${threadName}] ${preview}`
        },
        data: {
          chatID,
          messageID,
          threadName,
          senderUID,
          clubID,
          clubName,
          senderName,
          preview
        }
      };

      return admin.messaging().sendEachForMulticast({
        tokens,
        ...payload
      });

    } catch (err) {
      console.error("Error sending push notification:", err);
    }
  }
);
