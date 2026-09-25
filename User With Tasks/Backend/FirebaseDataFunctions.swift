import FirebaseDatabase
import Foundation

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
                operationID: "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)",
                expectedLastUpdated: nil
            )
            await onSaved?(nil)
        } catch {
            await onSaved?(error)
        }
    }
}

func observeSingleValue(at reference: DatabaseQuery) async -> DataSnapshot {
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

func appendUnique(_ value: String, to values: [String]) -> [String] {
    values.contains(value) ? values : values + [value]
}

func removeValue(_ value: String, from values: [String]) -> [String] {
    values.filter { $0 != value }
}

@discardableResult
func transactStringArray(
    at reference: DatabaseReference,
    update: @escaping ([String]) -> [String]
) async throws -> Bool {
    try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Bool, Error>) in
        reference.runTransactionBlock({ current in
            let values = current.value as? [String] ?? []
            let updated = update(values)
            guard updated != values else { return TransactionResult.abort() }
            current.value = updated.isEmpty ? NSNull() : updated
            return TransactionResult.success(withValue: current)
        }, andCompletionBlock: { error, committed, _ in
            if let error { continuation.resume(throwing: error) }
            else { continuation.resume(returning: committed) }
        }, withLocalEvents: false)
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
        do {
            try await transactStringArray(at: userFavoritesRef) {
                appendUnique(clubID, to: $0)
            }
        } catch {
            print("Error adding club to favorites: \(error)")
        }
    }
}

func removeClubFromFavorites(for userID: String, clubID: String) {
    let reference = Database.database().reference()
    let userFavoritesRef = reference.child("users").child(userID).child(
        "favoritedClubs"
    )

    Task {
        do {
            try await transactStringArray(at: userFavoritesRef) { values in
                let remaining = removeValue(clubID, from: values)
                return remaining.isEmpty ? [""] : remaining
            }
        } catch {
            print("Error removing club from favorites: \(error)")
        }
    }
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
        do {
            try await transactStringArray(at: peopleSeenRef) {
                appendUnique(memberEmail.lowercased(), to: $0)
            }
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
            startDate = meeting.startDate
            endDateExclusive = meeting.endDateExclusive
            startUtc = nil
            endUtc = nil
        } else {
            startUtc = meeting.startUtc
            endUtc = meeting.endUtc
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

private func performOwnMembershipAction(
    clubID: String,
    action: String,
    successTitle: String,
    errorTitle: String
) {
    Task {
        do {
            let _: MembershipMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "membership",
                body: MembershipMutationRequest(clubID: clubID, action: action)
            )
            await MainActor.run {
                dropper(title: successTitle, subtitle: "", icon: nil)
            }
        } catch {
            await MainActor.run {
                dropper(title: errorTitle, subtitle: error.localizedDescription, icon: nil)
            }
        }
    }
}

func addMemberToClub(clubID: String) {
    performOwnMembershipAction(
        clubID: clubID, action: "join", successTitle: "Joined Club!", errorTitle: "Could Not Join"
    )
}

func removeMemberFromClub(clubID: String) {
    performOwnMembershipAction(
        clubID: clubID, action: "leave", successTitle: "Club Left!", errorTitle: "Could Not Leave"
    )
}

func addPendingMemberRequest(clubID: String) {
    performOwnMembershipAction(
        clubID: clubID, action: "request", successTitle: "Requested Membership!",
        errorTitle: "Request Not Sent"
    )
}

func removePendingMemberRequest(clubID: String) {
    performOwnMembershipAction(
        clubID: clubID, action: "cancelRequest", successTitle: "Join Request Cancelled!",
        errorTitle: "Request Not Cancelled"
    )
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

func chat(
    from messagesSnapshot: DataSnapshot,
    chatID: String,
    clubID: String,
    pinned: [String]?
) -> Chat? {
    do {
        var messagesArray: [[String: Any]] = []
        if let messagesDict = messagesSnapshot.value as? [String: Any] {
            for (_, value) in messagesDict {
                if let messageData = value as? [String: Any] {
                    messagesArray.append(messageData)
                }
            }
        }
        messagesArray.sort {
            let date1 = $0["date"] as? Double ?? 0
            let date2 = $1["date"] as? Double ?? 0
            return date1 < date2
        }
        let chatDict: [String: Any] = [
            "chatID": chatID,
            "clubID": clubID,
            "messages": messagesArray,
            "pinned": pinned ?? [],
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: chatDict)
        return try JSONDecoder().decode(Chat.self, from: jsonData)
    } catch {
        print("Error decoding chat \(chatID): \(error)")
        return nil
    }
}

func fetchChatsMetaData(chatIds: [String]) async -> [Chat]? {
    let ref = Database.database().reference().child("chats")
    let uniqueIDs = Array(Set(chatIds)).sorted()

    let fetchedChats = await withTaskGroup(of: Chat?.self) { group in
        for chatID in uniqueIDs {
            group.addTask {
                let chatRef = ref.child(chatID)
                async let club = observeSingleValue(at: chatRef.child("clubID"))
                async let pinned = observeSingleValue(at: chatRef.child("pinned"))
                async let messages = observeSingleValue(
                    at: chatRef.child("messages")
                        .queryOrdered(byChild: "lastUpdated")
                        .queryLimited(toLast: 100)
                )
                let (clubSnapshot, pinnedSnapshot, messagesSnapshot) = await (
                    club, pinned, messages
                )
                guard let clubID = clubSnapshot.value as? String else { return nil }
                return chat(
                    from: messagesSnapshot,
                    chatID: chatID,
                    clubID: clubID,
                    pinned: pinnedSnapshot.value as? [String]
                )
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

    return fetchedChats.isEmpty ? nil : fetchedChats.sorted { $0.chatID < $1.chatID }
}

func createClubGroupChat(clubId: String) async -> Chat {
    let ref = Database.database().reference().child("chats")
    let clubsRef = Database.database().reference().child("clubs").child(clubId)
    let chatID = ref.childByAutoId().key ?? UUID().uuidString

    let newChat = Chat(
        chatID: chatID,
        clubID: clubId,
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

        do {
            if try await transactStringArray(at: clubsRef.child("chatIDs"), update: {
                appendUnique(chatID, to: $0)
            }) {
                try? await setFirebaseValue(
                    Date().timeIntervalSince1970,
                    at: clubsRef.child("lastUpdated")
                )
            }
        } catch {
            print("Failed to attach chat to club: \(error)")
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
    userID: String,
    isAdding: Bool
) async -> Bool {
    let messageRef = Database.database().reference().child("chats").child(
        chatID
    ).child("messages").child(messageID)
    let reactionRef = messageRef.child("reactions").child(emoji)
    let committed = await withCheckedContinuation {
        (continuation: CheckedContinuation<Bool, Never>) in
        reactionRef.runTransactionBlock({ current in
            let users = current.value as? [String] ?? []
            let updated = reactionUsers(users, userID: userID, isAdding: isAdding)
            current.value = updated.isEmpty ? NSNull() : updated
            return TransactionResult.success(withValue: current)
        }, andCompletionBlock: { error, committed, _ in
            if let error { print("Failed to update message reaction: \(error)") }
            continuation.resume(returning: error == nil && committed)
        }, withLocalEvents: false)
    }
    guard committed else { return false }
    do {
        try await setFirebaseValue(
            Date().timeIntervalSince1970,
            at: messageRef.child("lastUpdated")
        )
    } catch {
        print("Reaction saved, but its update time failed: \(error)")
    }
    return true
}

func reactionUsers(_ users: [String], userID: String, isAdding: Bool) -> [String] {
    if isAdding {
        return users.contains(userID) ? users : users + [userID]
    }
    return users.filter { $0 != userID }
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

    let pinnedSnapshot = await observeSingleValue(at: chatRef.child("pinned"))
    let pinned = pinnedSnapshot.value as? [String]

    var updates: [String: Any] = [
        "deletedMessages/\(messageID)": Date().timeIntervalSince1970,
        "messages/\(messageID)": NSNull(),
    ]

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

func threadDeletionUpdates(
    messageIDs: [String], pinned: [String]?, deletedAt: Double
) -> [String: Any] {
    var updates: [String: Any] = [:]
    let deletedIDs = Set(messageIDs)
    for messageID in deletedIDs {
        updates["messages/\(messageID)"] = NSNull()
        updates["deletedMessages/\(messageID)"] = deletedAt
    }
    if let pinned {
        let remaining = pinned.filter { !deletedIDs.contains($0) }
        if remaining.count != pinned.count {
            updates["pinned"] = remaining.isEmpty ? NSNull() : remaining
        }
    }
    return updates
}

func removeThread(chatID: String, threadName: String) {
    let chatRef = Database.database().reference().child("chats").child(chatID)

    Task {
        async let matchingSnapshot = observeSingleValue(
            at: chatRef.child("messages")
                .queryOrdered(byChild: "threadName")
                .queryEqual(toValue: threadName)
        )
        async let pinnedSnapshot = observeSingleValue(at: chatRef.child("pinned"))
        let (matching, pinned) = await (matchingSnapshot, pinnedSnapshot)
        guard let messages = matching.value as? [String: Any],
              !messages.isEmpty else { return }
        let updates = threadDeletionUpdates(
            messageIDs: Array(messages.keys),
            pinned: pinned.value as? [String],
            deletedAt: Date().timeIntervalSince1970
        )

        do {
            _ = try await chatRef.updateChildValues(updates)
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
