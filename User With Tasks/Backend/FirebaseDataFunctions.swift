import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseDatabaseInternal
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

private struct ClubSaveRequest: Encodable {
    let operationID: String
    let expectedLastUpdated: Double?
    let club: Club
}

private struct ClubSaveResponse: Decodable {
    let clubID: String
    let unresolved: [UnresolvedIdentity]

    struct UnresolvedIdentity: Decodable {
        let email: String
        let reason: String
    }
}

func saveClubThroughBackend(
    _ club: Club,
    operationID: String,
    expectedLastUpdated: Double?
) async throws {
    let _: ClubSaveResponse = try await PHSAPIClient.shared.request(
        "POST",
        path: "clubs/save",
        body: ClubSaveRequest(
            operationID: operationID,
            expectedLastUpdated: expectedLastUpdated,
            club: club
        )
    )
}

func addClub(club: Club, onSaved: (@MainActor (Error?) -> Void)? = nil) {
    var clubToSave = club
    clubToSave.lastUpdated = Date().timeIntervalSince1970
    Task {
        do {
            try await saveClubThroughBackend(
                clubToSave,
                operationID: UUID().uuidString,
                expectedLastUpdated: nil
            )
            await onSaved?(nil)
        } catch {
            await onSaved?(error)
        }
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

func setClubChatEnabled(clubID: String, enabled: Bool) async throws {
    let clubReference = Database.database().reference().child("clubs").child(
        clubID
    )

    _ = try await clubReference.updateChildValues([
        "chatEnabled": enabled,
        "lastUpdated": Date().timeIntervalSince1970,
    ])
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

func getClubNameByID(clubID: String) async -> String? {
    let reference = Database.database().reference().child("clubs").child(clubID).child("name")
    let snapshot = await observeSingleValue(at: reference)
    return snapshot.value as? String
}

func getClubNameByIDWithClubs(clubID: String, clubs: [Club]) -> String {
    var name = ""
    name = clubs.first(where: { $0.clubID == clubID })?.name ?? ""
    return name
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

private struct MeetingWritePayload: Encodable {
    let meetingID: String?
    let clubID: String
    let title: String
    let description: String
    let location: String
    let fullDay: Bool
    let startUtc: Double?
    let endUtc: Double?
    let startDate: String?
    let endDateExclusive: String?
    let timeZone = "America/Chicago"
    let visibilityMode: String
    let visibilityEmails: [String]
    let seriesID: String?
    let recurrenceIntervalWeeks: Int?
    let recurrenceEndDate: String?

    init(_ meeting: Club.MeetingTime) {
        meetingID = meeting.meetingID
        clubID = meeting.clubID
        title = meeting.title
        description = meeting.description ?? ""
        location = meeting.location ?? ""
        fullDay = meeting.fullDay == true
        seriesID = meeting.seriesID
        recurrenceIntervalWeeks = meeting.recurrenceIntervalWeeks
        recurrenceEndDate = meeting.recurrenceEndDate
        visibilityMode = meeting.visibility?.mode
            ?? ((meeting.visibleByArray?.isEmpty == false) ? "uids" : "public")
        visibilityEmails = meeting.visibleByArray ?? []
        if fullDay {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/Chicago")!
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            let start = strictDateFromString(meeting.startTime)
            let end = strictDateFromString(meeting.endTime)
            startDate = start.map { formatter.string(from: $0) }
            endDateExclusive = end.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
                .map { formatter.string(from: $0) }
            startUtc = nil
            endUtc = nil
        } else {
            startUtc = strictDateFromString(meeting.startTime)?.timeIntervalSince1970
            endUtc = strictDateFromString(meeting.endTime)?.timeIntervalSince1970
            startDate = nil
            endDateExclusive = nil
        }
    }
}

private struct SaveMeetingRequest: Encodable {
    let operationID: String
    let meetings: [MeetingWritePayload]
    let replacingClubID: String?
    let replacingMeetingID: String?
    let includingFuture: Bool
    let expectedRevision: Int?
}

private struct SavedMeetingsResponse: Decodable { let meetings: [Club.MeetingTime] }
private struct DeletedMeetingsResponse: Decodable { let deleted: [String] }

@MainActor
func addMeeting(meeting: Club.MeetingTime, intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in }) {
    saveMeetings(
        [meeting],
        replacing: nil,
        includingFuture: false,
        successTitle: "Added Meeting Time!",
        intent: intent, calendarStore: calendarStore,
        completion: completion
    )
}

@MainActor
func addMeetings(meetings: [Club.MeetingTime], intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in }) {
    saveMeetings(
        meetings,
        replacing: nil,
        includingFuture: false,
        successTitle: "Added Meeting Times!",
        intent: intent, calendarStore: calendarStore,
        completion: completion
    )
}

@MainActor
func replaceMeeting(oldMeeting: Club.MeetingTime, newMeeting: Club.MeetingTime, intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in })
{
    saveMeetings(
        [newMeeting],
        replacing: oldMeeting,
        includingFuture: false,
        successTitle: "Added Meeting Time!",
        intent: intent, calendarStore: calendarStore,
        completion: completion
    )
}

@MainActor
func replaceMeeting(
    oldMeeting: Club.MeetingTime,
    newMeetings: [Club.MeetingTime],
    intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in }
) {
    saveMeetings(
        newMeetings,
        replacing: oldMeeting,
        includingFuture: false,
        successTitle: "Edited Meeting Times!",
        intent: intent, calendarStore: calendarStore,
        completion: completion
    )
}

@MainActor
func replaceMeetingAndFuture(
    oldMeeting: Club.MeetingTime,
    newMeetings: [Club.MeetingTime],
    intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in }
) {
    saveMeetings(
        newMeetings,
        replacing: oldMeeting,
        includingFuture: true,
        successTitle: "Edited Meeting Times!",
        intent: intent, calendarStore: calendarStore,
        completion: completion
    )
}

@MainActor
func deleteMeeting(
    _ meetingToDelete: Club.MeetingTime,
    includingFuture: Bool,
    intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in }
) {
    guard !intent.isRunning else { return }
    intent.isRunning = true
    Task {
        defer { intent.isRunning = false }
        do {
            let scope = try MeetingMutationIntent.currentScope()
            guard let meetingID = meetingToDelete.meetingID else {
                throw PHSAPIError.server(status: 409, message: "Refresh the calendar before deleting this legacy meeting.")
            }
            struct Request: Encodable {
                let operationID: String
                let clubID: String
                let meetingID: String
                let includingFuture: Bool
            }
            let payload = try intent.prepare(scope: scope, path: "meetings/delete") { operationID in
                Request(operationID: operationID, clubID: meetingToDelete.clubID,
                        meetingID: meetingID, includingFuture: includingFuture)
            }
            let response: DeletedMeetingsResponse = try await PHSAPIClient.shared.request(
                "POST", path: "meetings/delete",
                body: payload
            )

            guard try MeetingMutationIntent.currentScope() == scope else { throw PHSAPIError.signedOut }
            intent.confirm()
            calendarStore.acceptMutation(saved: [], deleted: response.deleted, uid: scope.uid, projectID: scope.projectID)
            await MainActor.run {
                dropper(
                    title: includingFuture
                        ? "Deleted Meeting Times!" : "Deleted Meeting Time!",
                    subtitle: "",
                    icon: nil
                )
                completion(true)
            }
        } catch {
            intent.handleFailure(error)
            await MainActor.run {
                dropper(title: "Meeting Not Deleted", subtitle: error.localizedDescription, icon: nil)
                completion(false)
            }
        }
    }
}

@MainActor
func saveMeetings(
    _ newMeetings: [Club.MeetingTime],
    replacing oldMeeting: Club.MeetingTime?,
    includingFuture: Bool,
    successTitle: String,
    intent: MeetingMutationIntent,
    calendarStore: CalendarDataStore,
    completion: @escaping (Bool) -> Void = { _ in }
) {
    guard !newMeetings.isEmpty else { completion(false); return }
    guard !intent.isRunning else { return }
    intent.isRunning = true
    Task {
        defer { intent.isRunning = false }
        do {
            let scope = try MeetingMutationIntent.currentScope()
            let payload = try intent.prepare(scope: scope, path: "meetings/save") { operationID in
                SaveMeetingRequest(
                operationID: operationID,
                meetings: newMeetings.map(MeetingWritePayload.init),
                replacingClubID: oldMeeting?.clubID,
                replacingMeetingID: oldMeeting?.meetingID,
                includingFuture: includingFuture,
                expectedRevision: oldMeeting?.revision
            )
            }
            let response: SavedMeetingsResponse = try await PHSAPIClient.shared.request(
                "POST", path: "meetings/save", body: payload
            )
            guard try MeetingMutationIntent.currentScope() == scope else { throw PHSAPIError.signedOut }
            intent.confirm()
            calendarStore.acceptMutation(saved: response.meetings, deleted: [], uid: scope.uid, projectID: scope.projectID)
            await MainActor.run {
                dropper(title: successTitle, subtitle: "", icon: nil)
                completion(true)
            }
        } catch {
            intent.handleFailure(error)
            await MainActor.run {
                dropper(title: "Meeting Not Saved", subtitle: error.localizedDescription, icon: nil)
                completion(false)
            }
        }
    }
}

func meetings(from snapshot: DataSnapshot) -> [Club.MeetingTime] {
    guard JSONSerialization.isValidJSONObject(snapshot.value as Any),
        let data = try? JSONSerialization.data(withJSONObject: snapshot.value as Any)
    else { return [] }

    do {
        return try JSONDecoder().decode([Club.MeetingTime].self, from: data)
    } catch {
        print("Error decoding meeting data: \(error)")
        return []
    }
}

func addMemberToClub(clubID: String, memberEmail: String) {
    Task {
        do {
            let _: MembershipMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "membership",
                body: MembershipMutationRequest(clubID: clubID, action: "join")
            )
            await MainActor.run {
                dropper(title: "Joined Club!", subtitle: "", icon: nil)
            }
        } catch {
            await MainActor.run { dropper(title: "Could Not Join", subtitle: error.localizedDescription, icon: nil) }
        }
    }
}

func removeMemberFromClub(clubID: String, emailToRemove: String) {
    Task {
        do {
            let _: MembershipMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "membership",
                body: MembershipMutationRequest(clubID: clubID, action: "leave")
            )
            await MainActor.run {
                dropper(title: "Club Left!", subtitle: "", icon: nil)
            }
        } catch {
            await MainActor.run { dropper(title: "Could Not Leave", subtitle: error.localizedDescription, icon: nil) }
        }
    }
}

func addPendingMemberRequest(clubID: String, memberEmail: String) {
    Task {
        do {
            let _: MembershipMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "membership",
                body: MembershipMutationRequest(clubID: clubID, action: "request")
            )
            await MainActor.run {
                dropper(
                    title: "Requested Membership!",
                    subtitle: "",
                    icon: nil
                )
            }
        } catch {
            await MainActor.run { dropper(title: "Request Not Sent", subtitle: error.localizedDescription, icon: nil) }
        }
    }
}

func removePendingMemberRequest(clubID: String, emailToRemove: String) {
    Task {
        do {
            let _: MembershipMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "membership",
                body: MembershipMutationRequest(clubID: clubID, action: "cancelRequest")
            )
            await MainActor.run {
                dropper(
                    title: "Join Request Cancelled!", subtitle: "", icon: nil
                )
            }
        } catch {
            await MainActor.run { dropper(title: "Request Not Cancelled", subtitle: error.localizedDescription, icon: nil) }
        }
    }
}

private struct MembershipMutationRequest: Encodable {
    let clubID: String
    let action: String
    var targetUID: String? = nil
    var targetEmail: String? = nil
}

private struct MembershipMutationResponse: Decodable { let ok: Bool }

func resolveMembershipRequest(
    clubID: String,
    email: String,
    accepted: Bool,
    completion: (@MainActor (Bool) -> Void)? = nil
) {
    Task {
        do {
            let _: MembershipMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "membership",
                body: MembershipMutationRequest(
                    clubID: clubID,
                    action: accepted ? "approve" : "reject",
                    targetEmail: normalizedEmail(email)
                )
            )
            await completion?(true)
        } catch {
            await MainActor.run {
                dropper(title: "Request Not Updated", subtitle: error.localizedDescription, icon: nil)
            }
            await completion?(false)
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

@discardableResult
func updateMessageReaction(
    chatID: String,
    messageID: String,
    emoji: String,
    userIDs: [String]
) async -> Bool {
    let messageRef = Database.database().reference().child("chats").child(
        chatID
    ).child("messages").child(messageID)

    do {
        _ = try await messageRef.updateChildValues([
            "reactions/\(emoji)": userIDs.isEmpty ? NSNull() : userIDs,
            "lastUpdated": Date().timeIntervalSince1970,
        ])
        return true
    } catch {
        print("Failed to update message reaction: \(error)")
        return false
    }
}

@discardableResult
func updateMessagePollVote(
    chatID: String,
    messageID: String,
    userID: String,
    optionID: String
) async -> Bool {
    let messageRef = Database.database().reference().child("chats").child(
        chatID
    ).child("messages").child(messageID)

    do {
        _ = try await messageRef.updateChildValues([
            "poll/votes/\(userID)": optionID,
            "lastUpdated": Date().timeIntervalSince1970,
        ])
        return true
    } catch {
        print("Failed to update poll vote: \(error)")
        return false
    }
}

@discardableResult
func removeMessage(chatID: String, messageID: String) async -> Bool {
    let chatRef = Database.database().reference().child("chats").child(chatID)

    async let lastMessageIDSnapshot = observeSingleValue(
        at: chatRef.child("lastMessage").child("messageID")
    )
    async let pinnedSnapshot = observeSingleValue(at: chatRef.child("pinned"))

    let (lastMessageID, pinned) = await (
        lastMessageIDSnapshot.value as? String,
        pinnedSnapshot.value as? [String]
    )

    var updates: [String: Any] = [
        "deletedMessages/\(messageID)": Date().timeIntervalSince1970,
        "messages/\(messageID)": NSNull(),
    ]

    if lastMessageID == messageID {
        updates["lastMessage"] = NSNull()
    }

    if let pinned, pinned.contains(messageID) {
        let remainingPinned = pinned.filter { $0 != messageID }
        updates["pinned"] = remainingPinned.isEmpty ? NSNull() : remainingPinned
    }

    do {
        _ = try await chatRef.updateChildValues(updates)
        return true
    } catch {
        print("Failed to remove message: \(error)")
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

        var updates: [String: Any] = [:]
        for (messageID, messageData) in messagesDict {
            if let messageThread = messageData["threadName"] as? String,
                messageThread == threadName
            {
                updates[messageID] = NSNull()
            }
        }

        guard !updates.isEmpty else { return }

        do {
            _ = try await messagesRef.updateChildValues(updates)
            print("Removed thread \(threadName) from chat \(chatID)")
        } catch {
            print("Error removing thread \(threadName): \(error)")
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
