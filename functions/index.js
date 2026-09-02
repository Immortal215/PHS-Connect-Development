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
      if (clubData.chatEnabled === false) return;

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
        const clubSnap = await admin.database().ref(`/clubs/${clubID}`).once("value");
        const clubData = clubSnap.val();
        if (clubData && clubData.chatEnabled === false) return;
        clubName = (clubData && clubData.name) || "Reaction";
      }
        const messageSnap = await admin
          .database()
          .ref(`/chats/${chatID}/messages/${messageID}`)
          .once("value");

        const message = messageSnap.val();
        if (!message) return;

        const threadName = message.threadName || "general";
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
          threadName,
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

function meetingsFromSnapshot(snapshot) {
  if (!snapshot.exists()) return [];

  const value = snapshot.val();
  if (Array.isArray(value)) return value.filter(Boolean);
  return Object.values(value || {}).filter(Boolean);
}

function canonicalValue(value) {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (!value || typeof value !== "object") return value;

  return Object.keys(value)
    .sort()
    .reduce((result, key) => {
      result[key] = canonicalValue(value[key]);
      return result;
    }, {});
}

function changedMeetings(beforeMeetings, afterMeetings) {
  const beforeKeys = new Set(
    beforeMeetings.map((meeting) => JSON.stringify(canonicalValue(meeting)))
  );
  const afterKeys = new Set(
    afterMeetings.map((meeting) => JSON.stringify(canonicalValue(meeting)))
  );

  return {
    added: afterMeetings.filter(
      (meeting) => !beforeKeys.has(JSON.stringify(canonicalValue(meeting)))
    ),
    removed: beforeMeetings.filter(
      (meeting) => !afterKeys.has(JSON.stringify(canonicalValue(meeting)))
    ),
  };
}

function meetingDateTimeParts(value) {
  const match = /^(\d{2})-(\d{2})-(\d{4}),\s*(\d{1,2}:\d{2}\s*[AP]M)$/i.exec(
    value || ""
  );
  if (!match) return null;

  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  const month = months[Number(match[1]) - 1];
  if (!month) return null;

  return {
    date: `${month} ${Number(match[2])}, ${match[3]}`,
    time: match[4].replace(/\s+/g, " ").toUpperCase(),
  };
}

function meetingDateTimeText(meeting) {
  const start = meetingDateTimeParts(meeting.startTime);
  const end = meetingDateTimeParts(meeting.endTime);

  if (!start || !end) {
    return `${meeting.startTime || ""} - ${meeting.endTime || ""}`.trim();
  }

  if (start.date === end.date) {
    return `${start.date}, ${start.time} - ${end.time}`;
  }

  return `${start.date}, ${start.time} - ${end.date}, ${end.time}`;
}

exports.sendMeetingNotification = onValueWritten(
  "/clubs/{clubID}/meetingTimes",
  async (event) => {
    const clubID = event.params.clubID;
    const beforeMeetings = meetingsFromSnapshot(event.data.before);
    const afterMeetings = meetingsFromSnapshot(event.data.after);
    const changes = changedMeetings(beforeMeetings, afterMeetings);

    // Deletions do not create a meeting notification.
    if (changes.added.length === 0) return;

    const meeting = changes.added.sort((first, second) =>
      (first.startTime || "").localeCompare(second.startTime || "")
    )[0];
    const isEdit = changes.removed.length > 0;
    const isRepeating = Boolean(meeting.seriesID);

    try {
      const clubSnap = await admin.database().ref(`/clubs/${clubID}`).once("value");
      const club = clubSnap.val();
      if (!club) return;

      const usersSnap = await admin.database().ref("/users").once("value");
      const users = usersSnap.val() || {};
      const memberEmails = new Set([
        ...(club.members || []),
        ...(club.leaders || []),
      ]);
      const visibleEmails = Array.isArray(meeting.visibleByArray)
        ? new Set(meeting.visibleByArray)
        : null;
      const tokens = new Set();

      for (const user of Object.values(users)) {
        if (!user || !user.fcmToken || !memberEmails.has(user.userEmail)) continue;
        if (visibleEmails && !visibleEmails.has(user.userEmail)) continue;
        tokens.add(user.fcmToken);
      }

      if (tokens.size === 0) return;

      const action = isEdit ? "Updated" : "Created";
      const eventType = isRepeating ? "repeating event" : "meeting";
      const meetingSummary = `${action} ${eventType}: ${meeting.title || "Club Meeting"}`;
      const dateTimeSummary = meetingDateTimeText(meeting);
      const body = `${meetingSummary}\n${dateTimeSummary}`;
      const tokenList = Array.from(tokens);
      const sends = [];

      for (let index = 0; index < tokenList.length; index += 500) {
        sends.push(
          admin.messaging().sendEachForMulticast({
            tokens: tokenList.slice(index, index + 500),
            notification: {
              title: club.name || "Meeting Update",
              body,
            },
            data: {
              type: "meeting",
              clubID,
              clubName: club.name || "",
              meetingTitle: meeting.title || "",
              startTime: meeting.startTime || "",
            },
          })
        );
      }

      return Promise.all(sends);
    } catch (err) {
      console.error("Error sending meeting notification:", err);
    }
  }
);
