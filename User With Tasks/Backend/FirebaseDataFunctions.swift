import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseDatabaseInternal
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

func addClub(club: Club) {
    let reference = Database.database().reference()
    let clubReference = reference.child("clubs").child(club.clubID)

    var clubToSave = club
    clubToSave.lastUpdated = Date().timeIntervalSince1970

    do {
        let data = try JSONEncoder().encode(clubToSave)
        if let dictionary = try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        {
            Task {
                do {
                    try await setFirebaseValue(dictionary, at: clubReference)
                } catch {
                    print("Error saving club data: \(error)")
                }
            }
        }
    } catch {
        print("Error encoding club data: \(error)")
    }
}

func observeSingleValue(at reference: DatabaseReference) async -> DataSnapshot {
    await withCheckedContinuation { continuation in
        reference.observeSingleEvent(of: .value) { snapshot in
            continuation.resume(returning: snapshot)
        }
    }
}

func setFirebaseValue(_ value: Any?, at reference: DatabaseReference) async throws {
    try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        reference.setValue(value) { error, _ in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }
}

func personal(from snapshot: DataSnapshot, userID: String) -> Personal? {
    if let value = snapshot.value as? [String: Any] {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: value)
            return try JSONDecoder().decode(Personal.self, from: jsonData)
        } catch {
            print("Error decoding user data: \(error)")
            return nil
        }
    } else {
        print("No user found for userID: \(userID)")
        return nil
    }
}

func fetchUser(for userID: String) async -> Personal? {
    let reference = Database.database().reference().child("users").child(userID)
    let snapshot = await observeSingleValue(at: reference)
    return personal(from: snapshot, userID: userID)
}

func addClubToFavorites(for userID: String, clubID: String) {
    let reference = Database.database().reference()
    let userFavoritesRef = reference.child("users").child(userID).child(
        "favoritedClubs"
    )

    Task {
        let snapshot = await observeSingleValue(at: userFavoritesRef)
        var favorites = snapshot.value as? [String] ?? []

        if !favorites.contains(clubID) {
            favorites.append(clubID)
            do {
                try await setFirebaseValue(favorites, at: userFavoritesRef)
                print("Club added to favorites successfully")
            } catch {
                print("Error adding club to favorites: \(error)")
            }
        } else {
            print("Club is already in favorites")
        }
    }
}

func removeClubFromFavorites(for userID: String, clubID: String) {
    let reference = Database.database().reference()
    let userFavoritesRef = reference.child("users").child(userID).child(
        "favoritedClubs"
    )

    Task {
        let snapshot = await observeSingleValue(at: userFavoritesRef)
        var favorites = snapshot.value as? [String] ?? []

        if let index = favorites.firstIndex(of: clubID) {
            favorites.remove(at: index)
            do {
                try await setFirebaseValue(favorites, at: userFavoritesRef)
                print("Club removed from favorites successfully")
            } catch {
                print("Error removing club from favorites: \(error)")
            }
        } else {
            print("Club was not in favorites")
        }
    }
}

func clubIDByName(from snapshot: DataSnapshot, clubName: String) -> String? {
    for child in snapshot.children {
        if let snap = child as? DataSnapshot,
            let clubData = snap.value as? [String: Any],
            let name = clubData["name"] as? String,
            name == clubName
        {
            return snap.key
        }
    }

    return nil
}

func getClubIDByName(clubName: String) async -> String? {
    let reference = Database.database().reference().child("clubs")
    let snapshot = await observeSingleValue(at: reference)
    return clubIDByName(from: snapshot, clubName: clubName)
}

func clubName(from snapshot: DataSnapshot) -> String? {
    guard let clubData = snapshot.value as? [String: Any],
        let clubName = clubData["name"] as? String
    else {
        return nil
    }

    return clubName
}

func getClubNameByID(clubID: String) async -> String? {
    let reference = Database.database().reference().child("clubs").child(clubID)
    let snapshot = await observeSingleValue(at: reference)
    return clubName(from: snapshot)
}

func getClubNameByIDWithClubs(clubID: String, clubs: [Club]) -> String {
    var name = ""
    name = clubs.first(where: { $0.clubID == clubID })?.name ?? ""
    return name
}

func getFavoritedClubNames(from clubIDs: [String]) async -> [String] {
    await withTaskGroup(of: String?.self) { group in
        for clubID in clubIDs {
            group.addTask {
                await getClubNameByID(clubID: clubID)
            }
        }

        var clubNames: [String] = []
        for await clubName in group {
            if let clubName {
                clubNames.append(clubName)
            }
        }

        return clubNames
    }
}

func addAnnouncement(announcement: Club.Announcements) {
    let reference = Database.database().reference()
    let announcementReference = reference.child("clubs").child(
        announcement.clubID
    ).child("announcements")

    do {
        let data = try JSONEncoder().encode(announcement)
        if let dictionary = try JSONSerialization.jsonObject(
            with: data,
            options: []
        ) as? [String: Any] {
            Task {
                do {
                    try await setFirebaseValue(
                        dictionary,
                        at: announcementReference.child(announcement.date)
                    )
                    // also update lastUpdated
                    try? await setFirebaseValue(
                        Date().timeIntervalSince1970,
                        at: reference.child("clubs")
                            .child(announcement.clubID)
                            .child("lastUpdated")
                    )
                } catch {
                    print("Error saving announcement data: \(error)")
                }
            }
        }
    } catch {
        print("Error encoding announcement data: \(error)")
    }
}

func addPersonSeen(announcement: Club.Announcements, memberEmail: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(announcement.clubID).child(
        "announcements"
    ).child(announcement.date)

    Task {
        let peopleSeenRef = clubRef.child("peopleSeen")
        let snapshot = await observeSingleValue(at: peopleSeenRef)
        var peopleSeen = snapshot.value as? [String] ?? []

        if peopleSeen.contains(memberEmail.lowercased()) {
            print("Error: Member already in the peopleSeen.")
            return
        }

        peopleSeen.append(memberEmail.lowercased())

        do {
            try await setFirebaseValue(Array(Set(peopleSeen)), at: peopleSeenRef)
            print("Member added to peopleseen successfully.")
        } catch {
            print(
                "Error adding member to peopleseen: \(error.localizedDescription)"
            )
        }
    }
}

func addMeeting(meeting: Club.MeetingTime) {
    let reference = Database.database().reference()
    let clubReference = reference.child("clubs").child(meeting.clubID)

    Task {
        let meetingTimesRef = clubReference.child("meetingTimes")
        let snapshot = await observeSingleValue(at: meetingTimesRef)
        var currentMeetings: [[String: Any]] = []

        if let existingMeetings = snapshot.value as? [[String: Any]] {
            currentMeetings = existingMeetings
        }

        do {
            let data = try JSONEncoder().encode(meeting)
            if let meetingDict = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
            {
                currentMeetings.append(meetingDict)
                try await setFirebaseValue(currentMeetings, at: meetingTimesRef)
                try? await setFirebaseValue(
                    Date().timeIntervalSince1970,
                    at: clubReference.child("lastUpdated")
                )
                await MainActor.run {
                    dropper(
                        title: "Added Meeting Time!",
                        subtitle: "",
                        icon: nil
                    )
                }
            }
        } catch {
            print("Error encoding meeting data: \(error)")
        }
    }
}

func replaceMeeting(oldMeeting: Club.MeetingTime, newMeeting: Club.MeetingTime)
{
    let reference = Database.database().reference()

    let oldClubReference = reference.child("clubs").child(oldMeeting.clubID)

    Task {
        let meetingTimesRef = oldClubReference.child("meetingTimes")
        let snapshot = await observeSingleValue(at: meetingTimesRef)
        guard var currentMeetings = snapshot.value as? [[String: Any]] else {
            print("No meetings found in the current club.")
            return
        }

        currentMeetings.removeAll { meetingDict in
            if let title = meetingDict["title"] as? String,
                let startTime = meetingDict["startTime"] as? String,
                let endTime = meetingDict["endTime"] as? String
            {
                return title == oldMeeting.title
                    && startTime == oldMeeting.startTime
                    && endTime == oldMeeting.endTime
            }
            return false
        }

        do {
            try await setFirebaseValue(currentMeetings, at: meetingTimesRef)
            addMeeting(meeting: newMeeting)
        } catch {
            print("Error removing old meeting: \(error)")
        }
    }
}

func addMemberToClub(clubID: String, memberEmail: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)

    Task {
        let membersRef = clubRef.child("members")
        let snapshot = await observeSingleValue(at: membersRef)
        var members = snapshot.value as? [String] ?? []

        if members.contains(memberEmail.lowercased()) {
            print("Error: Member already in the members.")
            return
        }

        members.append(memberEmail.lowercased())

        do {
            try await setFirebaseValue(Array(Set(members)), at: membersRef)
            print("Member added successfully.")
            try? await setFirebaseValue(
                Date().timeIntervalSince1970,
                at: clubRef.child("lastUpdated")
            )
            await MainActor.run {
                dropper(title: "Joined Club!", subtitle: "", icon: nil)
            }
        } catch {
            print(
                "Error adding member to members: \(error.localizedDescription)"
            )
        }
    }
}

func removeMemberFromClub(clubID: String, emailToRemove: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)

    Task {
        let membersRef = clubRef.child("members")
        let snapshot = await observeSingleValue(at: membersRef)
        var members = snapshot.value as? [String] ?? []

        if let index = members.firstIndex(of: emailToRemove.lowercased()) {
            members.remove(at: index)

            do {
                try await setFirebaseValue(members, at: membersRef)
                try? await setFirebaseValue(
                    Date().timeIntervalSince1970,
                    at: clubRef.child("lastUpdated")
                )
                print("Email removed successfully.")
                await MainActor.run {
                    dropper(title: "Club Left!", subtitle: "", icon: nil)
                }
            } catch {
                print("Error removing email: \(error.localizedDescription)")
            }
        } else {
            print("Error: Email not found in the club.")
        }
    }
}

func addPendingMemberRequest(clubID: String, memberEmail: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)

    Task {
        let pendingRequestsRef = clubRef.child("pendingMemberRequests")
        let snapshot = await observeSingleValue(at: pendingRequestsRef)
        var pendingRequests = snapshot.value as? [String] ?? []

        if pendingRequests.contains(memberEmail.lowercased()) {
            print("Error: Member already in the pending requests.")
            return
        }

        pendingRequests.append(memberEmail.lowercased())

        do {
            try await setFirebaseValue(
                Array(Set(pendingRequests)),
                at: pendingRequestsRef
            )
            print("Member added to pending requests successfully.")
            try? await setFirebaseValue(
                Date().timeIntervalSince1970,
                at: clubRef.child("lastUpdated")
            )
            await MainActor.run {
                dropper(
                    title: "Requested Membership!",
                    subtitle: "",
                    icon: nil
                )
            }
        } catch {
            print(
                "Error adding member to pending requests: \(error.localizedDescription)"
            )
        }
    }
}

func removePendingMemberRequest(clubID: String, emailToRemove: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)

    Task {
        let pendingRequestsRef = clubRef.child("pendingMemberRequests")
        let snapshot = await observeSingleValue(at: pendingRequestsRef)
        var pendingRequests = snapshot.value as? [String] ?? []

        if let index = pendingRequests.firstIndex(
            of: emailToRemove.lowercased()
        ) {
            pendingRequests.remove(at: index)

            do {
                try await setFirebaseValue(
                    pendingRequests,
                    at: pendingRequestsRef
                )
                try? await setFirebaseValue(
                    Date().timeIntervalSince1970,
                    at: clubRef.child("lastUpdated")
                )
                print("Email removed from pending requests successfully.")
                await MainActor.run {
                    dropper(
                        title: "Join Request Cancelled!",
                        subtitle: "",
                        icon: nil
                    )
                }
            } catch {
                print(
                    "Error removing email from pending requests: \(error.localizedDescription)"
                )
            }
        } else {
            print("Error: Email not found in pending requests.")
        }
    }
}

func addLocationCoords(clubID: String, locationCoords: [Double]) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)

    Task {
        do {
            try await setFirebaseValue(
                locationCoords,
                at: clubRef.child("locationInSchoolCoordinates")
            )
            try? await setFirebaseValue(
                Date().timeIntervalSince1970,
                at: clubRef.child("lastUpdated")
            )
            print("Added coords successfully.")
            await MainActor.run {
                dropper(
                    title: "Location Edited Successfully!",
                    subtitle: "",
                    icon: nil
                )
            }
        } catch {
            print("Error adding coords : \(error.localizedDescription)")
        }
    }
}

func chat(from snapshot: DataSnapshot, chatID: String) -> Chat? {
    guard let dict = snapshot.value as? [String: Any] else { return nil }

    do {
        var chatDict = dict
        if let messagesDict = chatDict["messages"] as? [String: Any] {
            var messagesArray: [[String: Any]] = []
            for (_, value) in messagesDict {
                if let messageData = value as? [String: Any] {
                    messagesArray.append(messageData)
                }
            }
            messagesArray.sort {
                let date1 = $0["date"] as? Double ?? 0
                let date2 = $1["date"] as? Double ?? 0
                return date1 < date2
            }
            chatDict["messages"] = messagesArray
        }

        let jsonData = try JSONSerialization.data(withJSONObject: chatDict)
        return try JSONDecoder().decode(Chat.self, from: jsonData)
    } catch {
        print("Error decoding chat \(chatID): \(error)")
        return nil
    }
}

func fetchChatsMetaData(chatIds: [String]) async -> [Chat]? {
    let ref = Database.database().reference().child("chats")

    let fetchedChats = await withTaskGroup(of: Chat?.self) { group in
        for chatID in chatIds {
            group.addTask {
                let snapshot = await observeSingleValue(at: ref.child(chatID))
                return chat(from: snapshot, chatID: chatID)
            }
        }

        var chats: [Chat] = []
        for await chat in group {
            if let chat {
                chats.append(chat)
            }
        }

        return chats
    }

    return fetchedChats.isEmpty ? nil : fetchedChats
}

func createClubGroupChat(
    clubId: String,
    messageTo: String?
) async -> Chat {
    let ref = Database.database().reference().child("chats")
    let clubsRef = Database.database().reference().child("clubs").child(clubId)
    let chatID = ref.childByAutoId().key ?? UUID().uuidString

    let newChat = Chat(
        chatID: chatID,
        clubID: clubId,
        directMessageTo: messageTo,
        messages: []
    )

    guard var chatDict = try? DictionaryEncoder().encode(newChat) else {
        print("Failed to encode chat")
        return newChat
    }

    chatDict.removeValue(forKey: "messages")

    do {
        try await setFirebaseValue(chatDict, at: ref.child(chatID))
        print("Chat created successfully")

        let snapshot = await observeSingleValue(at: clubsRef.child("chatIDs"))
        var chatIDs = snapshot.value as? [String] ?? []
        if !chatIDs.contains(chatID) {
            chatIDs.append(chatID)
            do {
                try await setFirebaseValue(chatIDs, at: clubsRef.child("chatIDs"))
                try? await setFirebaseValue(
                    Date().timeIntervalSince1970,
                    at: clubsRef.child("lastUpdated")
                )
            } catch {
                print("Failed to attach chat to club: \(error)")
            }
        }
    } catch {
        print("Failed to create chat: \(error)")
    }

    return newChat
}

struct DictionaryEncoder {
    func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
            ?? [:]
    }
}

@discardableResult
func sendMessage(
    chatID: String,
    message: Chat.ChatMessage
) async -> Bool {
    let messagesRef = Database.database().reference().child("chats").child(
        chatID
    ).child("messages")

    var messageToSend = message
    messageToSend.lastUpdated = Date().timeIntervalSince1970

    let messageRef: DatabaseReference
    if !messageToSend.messageID.isEmpty && messageToSend.messageID != String() {
        messageRef = messagesRef.child(messageToSend.messageID)
    } else {
        messageRef = messagesRef.childByAutoId()
        messageToSend.setMessageID(messageRef.key ?? "ERROR")
    }

    guard let messageDict = try? DictionaryEncoder().encode(messageToSend)
    else {
        print("Failed to encode message")
        return false
    }

    do {
        try await setFirebaseValue(messageDict, at: messageRef)
        let chatRef = Database.database().reference().child("chats").child(
            chatID
        )

        let snapshot = await observeSingleValue(at: chatRef)
        var shouldUpdateLastMessage = true

        if let chatDict = snapshot.value as? [String: Any],
            let lastMessageDict = chatDict["lastMessage"] as? [String: Any],
            let lastTimestamp = lastMessageDict["date"] as? Double
        {
            // Only update if the new message is newer
            shouldUpdateLastMessage = messageToSend.date >= lastTimestamp  // >= for if editing a message
        }

        if shouldUpdateLastMessage {
            do {
                try await setFirebaseValue(
                    messageDict,
                    at: chatRef.child("lastMessage")
                )
            } catch {
                print("Failed to update last message: \(error)")
            }
        }

        return true
    } catch {
        print("Failed to send message: \(error)")
        return false
    }
}

func removeThread(chatID: String, threadName: String) {
    let messagesRef = Database.database().reference().child("chats").child(
        chatID
    ).child("messages")

    Task {
        let snapshot = await observeSingleValue(at: messagesRef)
        guard let messagesDict = snapshot.value as? [String: [String: Any]]
        else {
            print("No messages found for chat \(chatID)")
            return
        }

        for (messageID, messageData) in messagesDict {
            if let messageThread = messageData["threadName"] as? String,
                messageThread == threadName
            {
                do {
                    try await setFirebaseValue(
                        nil,
                        at: messagesRef.child(messageID)
                    )
                    print(
                        "Removed message \(messageID) from thread \(threadName)"
                    )
                } catch {
                    print("Error removing message \(messageID): \(error)")
                }
            }
        }
    }
}

func updateUserNotificationSettings(
    userID: String,
    chatNotifStyles: [String: Personal.ChatNotifStyle]?,
    mutedThreadsByChat: [String: [String]]?
) {
    let ref = Database.database().reference().child("users").child(userID)

    var updates: [String: Any] = [:]

    if let styles = chatNotifStyles {
        updates["chatNotifStyles"] = styles.mapValues { $0.rawValue }
    }

    if let muted = mutedThreadsByChat {
        updates["mutedThreadsByChat"] = muted
    }

    if !updates.isEmpty {
        ref.updateChildValues(updates)
    }
}
