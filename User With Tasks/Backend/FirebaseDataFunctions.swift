import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
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
        if let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            clubReference.setValue(dictionary)
        }
    } catch {
        print("Error encoding club data: \(error)")
    }
}

func fetchUser(for userID: String, completion: @escaping (Personal?) -> Void) {
    let reference = Database.database().reference().child("users").child(userID)
    
    reference.observeSingleEvent(of: .value) { snapshot in
        if let value = snapshot.value as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: value)
                let user = try JSONDecoder().decode(Personal.self, from: jsonData)
                completion(user)
            } catch {
                print("Error decoding user data: \(error)")
                completion(nil)
            }
        } else {
            print("No user found for userID: \(userID)")
            completion(nil)
        }
    }
}

func addClubToFavorites(for userID: String, clubID: String) {
    let reference = Database.database().reference()
    let userFavoritesRef = reference.child("users").child(userID).child("favoritedClubs")
    
    userFavoritesRef.observeSingleEvent(of: .value) { snapshot in
        var favorites = snapshot.value as? [String] ?? []
        
        if !favorites.contains(clubID) {
            favorites.append(clubID)
            userFavoritesRef.setValue(favorites) { error, _ in
                if let error = error {
                    print("Error adding club to favorites: \(error)")
                } else {
                    print("Club added to favorites successfully")
                }
            }
        } else {
            print("Club is already in favorites")
        }
    }
}

func removeClubFromFavorites(for userID: String, clubID: String) {
    let reference = Database.database().reference()
    let userFavoritesRef = reference.child("users").child(userID).child("favoritedClubs")
    
    userFavoritesRef.observeSingleEvent(of: .value) { snapshot in
        var favorites = snapshot.value as? [String] ?? []
        
        if let index = favorites.firstIndex(of: clubID) {
            favorites.remove(at: index)
            userFavoritesRef.setValue(favorites) { error, _ in
                if let error = error {
                    print("Error removing club from favorites: \(error)")
                } else {
                    print("Club removed from favorites successfully")
                }
            }
        } else {
            print("Club was not in favorites")
        }
    }
}

func getClubIDByName(clubName: String, completion: @escaping (String?) -> Void) {
    let reference = Database.database().reference().child("clubs")
    
    reference.observeSingleEvent(of: .value) { snapshot in
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let clubData = snap.value as? [String: Any],
               let name = clubData["name"] as? String,
               name == clubName {
                completion(snap.key)
                return
            }
        }
        
    }
}

func getClubNameByID(clubID: String, completion: @escaping (String?) -> Void) {
    let reference = Database.database().reference().child("clubs").child(clubID)
    
    reference.observeSingleEvent(of: .value) { snapshot in
        guard let clubData = snapshot.value as? [String: Any],
              let clubName = clubData["name"] as? String else {
            completion(nil)
            return
        }
        completion(clubName)
    }
}

func getClubNameByIDWithClubs(clubID: String, clubs: [Club]) -> String {
    var name = ""
    name = clubs.first(where: {$0.clubID == clubID })?.name ?? ""
    return name
}

func getFavoritedClubNames(from clubIDs: [String], completion: @escaping ([String]) -> Void) {
    var clubNames: [String] = []
    let group = DispatchGroup()
    
    for clubID in clubIDs {
        group.enter()
        getClubNameByID(clubID: clubID) { clubName in
            if let name = clubName {
                clubNames.append(name)
            }
            group.leave()
        }
    }
    
    group.notify(queue: .main) {
        completion(clubNames)
    }
}

func addAnnouncement(announcement: Club.Announcements) {
    let reference = Database.database().reference()
    let announcementReference = reference.child("clubs").child(announcement.clubID).child("announcements")
    
    do {
        let data = try JSONEncoder().encode(announcement)
        if let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            announcementReference.child(announcement.date).setValue(dictionary)
            // also update lastUpdated
            reference.child("clubs").child(announcement.clubID).child("lastUpdated").setValue(Date().timeIntervalSince1970)
        }
    } catch {
        print("Error encoding announcement data: \(error)")
    }
}

func addPersonSeen(announcement: Club.Announcements, memberEmail: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(announcement.clubID).child("announcements").child(announcement.date)
    
    clubRef.child("peopleSeen").observeSingleEvent(of: .value) { snapshot in
        var peopleSeen = snapshot.value as? [String] ?? []
        
        if peopleSeen.contains(memberEmail.lowercased()) {
            print("Error: Member already in the peopleSeen.")
            return
        }
        
        peopleSeen.append(memberEmail.lowercased())
        
        clubRef.child("peopleSeen").setValue(Array(Set(peopleSeen))) { error, _ in
            if let error = error {
                print("Error adding member to peopleseen: \(error.localizedDescription)")
            } else {
                print("Member added to peopleseen successfully.")
            }
        }
    }
}

func addMeeting(meeting: Club.MeetingTime) {
    let reference = Database.database().reference()
    let clubReference = reference.child("clubs").child(meeting.clubID)
    
    clubReference.child("meetingTimes").observeSingleEvent(of: .value) { snapshot in
        var currentMeetings: [[String: Any]] = []
        
        if let existingMeetings = snapshot.value as? [[String: Any]] {
            currentMeetings = existingMeetings
        }
        
        do {
            let data = try JSONEncoder().encode(meeting)
            if let meetingDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                currentMeetings.append(meetingDict)
                clubReference.child("meetingTimes").setValue(currentMeetings)
                clubReference.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                dropper(title: "Added Meeting Time!", subtitle: "", icon: nil)
            }
        } catch {
            print("Error encoding meeting data: \(error)")
        }
    }
}

func replaceMeeting(oldMeeting: Club.MeetingTime, newMeeting: Club.MeetingTime) {
    let reference = Database.database().reference()
    
    let oldClubReference = reference.child("clubs").child(oldMeeting.clubID)
    
    oldClubReference.child("meetingTimes").observeSingleEvent(of: .value) { snapshot in
        guard var currentMeetings = snapshot.value as? [[String: Any]] else {
            print("No meetings found in the current club.")
            return
        }
        
        currentMeetings.removeAll { meetingDict in
            if let title = meetingDict["title"] as? String,
               let startTime = meetingDict["startTime"] as? String,
               let endTime = meetingDict["endTime"] as? String {
                return title == oldMeeting.title &&
                startTime == oldMeeting.startTime &&
                endTime == oldMeeting.endTime
            }
            return false
        }
        
        oldClubReference.child("meetingTimes").setValue(currentMeetings) { error, _ in
            if let error = error {
                print("Error removing old meeting: \(error)")
            } else {
                addMeeting(meeting: newMeeting)
            }
        }
    }
}

func addMemberToClub(clubID: String, memberEmail: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)
    
    clubRef.child("members").observeSingleEvent(of: .value) { snapshot in
        var members = snapshot.value as? [String] ?? []
        
        if members.contains(memberEmail.lowercased()) {
            print("Error: Member already in the members.")
            return
        }
        
        members.append(memberEmail.lowercased())
        
        clubRef.child("members").setValue(Array(Set(members))) { error, _ in
            if let error = error {
                print("Error adding member to members: \(error.localizedDescription)")
            } else {
                print("Member added successfully.")
                clubRef.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                dropper(title: "Joined Club!", subtitle: "", icon: nil)
            }
        }
    }
}

func removeMemberFromClub(clubID: String, emailToRemove: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)
    
    clubRef.child("members").observeSingleEvent(of: .value) { snapshot in
        var members = snapshot.value as? [String] ?? []
        
        if let index = members.firstIndex(of: emailToRemove.lowercased()) {
            members.remove(at: index)
            
            clubRef.child("members").setValue(members) { error, _ in
                if let error = error {
                    print("Error removing email: \(error.localizedDescription)")
                } else {
                    clubRef.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                    print("Email removed successfully.")
                    dropper(title: "Club Left!", subtitle: "", icon: nil)
                }
            }
        } else {
            print("Error: Email not found in the club.")
        }
    }
}

func addPendingMemberRequest(clubID: String, memberEmail: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)
    
    clubRef.child("pendingMemberRequests").observeSingleEvent(of: .value) { snapshot in
        var pendingRequests = snapshot.value as? [String] ?? []
        
        if pendingRequests.contains(memberEmail.lowercased()) {
            print("Error: Member already in the pending requests.")
            return
        }
        
        pendingRequests.append(memberEmail.lowercased())
        
        clubRef.child("pendingMemberRequests").setValue(Array(Set(pendingRequests))) { error, _ in
            if let error = error {
                print("Error adding member to pending requests: \(error.localizedDescription)")
            } else {
                print("Member added to pending requests successfully.")
                clubRef.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                dropper(title: "Requested Membership!", subtitle: "", icon: nil)
            }
        }
    }
}

func removePendingMemberRequest(clubID: String, emailToRemove: String) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)
    
    clubRef.child("pendingMemberRequests").observeSingleEvent(of: .value) { snapshot in
        var pendingRequests = snapshot.value as? [String] ?? []
        
        if let index = pendingRequests.firstIndex(of: emailToRemove.lowercased()) {
            pendingRequests.remove(at: index)
            
            clubRef.child("pendingMemberRequests").setValue(pendingRequests) { error, _ in
                if let error = error {
                    print("Error removing email from pending requests: \(error.localizedDescription)")
                } else {
                    clubRef.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                    print("Email removed from pending requests successfully.")
                    dropper(title: "Join Request Cancelled!", subtitle: "", icon: nil)
                }
            }
        } else {
            print("Error: Email not found in pending requests.")
        }
    }
}

func addLocationCoords(clubID: String, locationCoords: [Double]) {
    let databaseRef = Database.database().reference()
    let clubRef = databaseRef.child("clubs").child(clubID)
    
    clubRef.child("locationInSchoolCoordinates").observeSingleEvent(of: .value) { snapshot in
        
        clubRef.child("locationInSchoolCoordinates").setValue(locationCoords) { error, _ in
            if let error = error {
                print("Error adding coords : \(error.localizedDescription)")
            } else {
                clubRef.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                print("Added coords successfully.")
                dropper(title: "Location Edited Successfully!", subtitle: "", icon: nil)
            }
        }
    }
}


func fetchChatsMetaData(chatIds: [String], completion: @escaping ([Chat]?) -> Void) {
    let ref = Database.database().reference().child("chats")
    var fetchedChats: [Chat] = []
    let group = DispatchGroup()

    for chatID in chatIds {
        group.enter()
        ref.child(chatID).observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
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
                    let chat = try JSONDecoder().decode(Chat.self, from: jsonData)
                    fetchedChats.append(chat)
                } catch {
                    print("Error decoding chat \(chatID): \(error)")
                }
            }
            group.leave()
        }
    }

    group.notify(queue: .main) {
        completion(fetchedChats.isEmpty ? nil : fetchedChats)
    }
}

func createClubGroupChat(clubId: String, messageTo: String?, completion: @escaping (Chat) -> Void) {
    let ref = Database.database().reference().child("chats")
    let clubsRef = Database.database().reference().child("clubs").child(clubId)
    let chatID = ref.childByAutoId().key ?? UUID().uuidString

    let newChat = Chat(chatID: chatID, clubID: clubId, directMessageTo: messageTo, messages: [])

    guard var chatDict = try? DictionaryEncoder().encode(newChat) else {
        print("Failed to encode chat")
        return
    }

    chatDict.removeValue(forKey: "messages")

    ref.child(chatID).setValue(chatDict) { error, _ in
        if let error = error {
            print("Failed to create chat: \(error)")
        } else {
            print("Chat created successfully")

            clubsRef.child("chatIDs").observeSingleEvent(of: .value) { snapshot in
                var chatIDs = snapshot.value as? [String] ?? []
                if !chatIDs.contains(chatID) {
                    chatIDs.append(chatID)
                    clubsRef.child("chatIDs").setValue(chatIDs)
                    clubsRef.child("lastUpdated").setValue(Date().timeIntervalSince1970)
                }
            }
        }
        completion(newChat)
    }
}


struct DictionaryEncoder {
    func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

func sendMessage(chatID: String, message: Chat.ChatMessage, completion: ((Bool) -> Void)? = nil) {
    let messagesRef = Database.database().reference().child("chats").child(chatID).child("messages")
    
    var messageToSend = message
    messageToSend.lastUpdated = Date().timeIntervalSince1970
    
    let messageRef: DatabaseReference
    if !messageToSend.messageID.isEmpty && messageToSend.messageID != String() {
        messageRef = messagesRef.child(messageToSend.messageID)
    } else {
        messageRef = messagesRef.childByAutoId()
        messageToSend.setMessageID(messageRef.key ?? "ERROR")
    }
    
    guard let messageDict = try? DictionaryEncoder().encode(messageToSend) else {
        print("Failed to encode message")
        completion?(false)
        return
    }
    
    messageRef.setValue(messageDict) { error, _ in
        if let error = error {
            print("Failed to send message: \(error)")
            completion?(false)
            return
        }
        
        let chatRef = Database.database().reference().child("chats").child(chatID)

        chatRef.observeSingleEvent(of: .value) { snapshot in
            var shouldUpdateLastMessage = true

            if let chatDict = snapshot.value as? [String: Any],
               let lastMessageDict = chatDict["lastMessage"] as? [String: Any],
               let lastTimestamp = lastMessageDict["date"] as? Double {
                // Only update if the new message is newer
                shouldUpdateLastMessage = messageToSend.date >= lastTimestamp // >= for if editing a message 
            }

            if shouldUpdateLastMessage {
                chatRef.child("lastMessage").setValue(messageDict)
            }

            completion?(true)
        }

        completion?(true)
    }
}

func removeThread(chatID: String, threadName: String) {
    let messagesRef = Database.database().reference().child("chats").child(chatID).child("messages")
    
    messagesRef.observeSingleEvent(of: .value) { snapshot in
        guard let messagesDict = snapshot.value as? [String: [String: Any]] else {
            print("No messages found for chat \(chatID)")
            return
        }
        
        for (messageID, messageData) in messagesDict {
            if let messageThread = messageData["threadName"] as? String,
               messageThread == threadName {
                messagesRef.child(messageID).removeValue { error, _ in
                    if let error = error {
                        print("Error removing message \(messageID): \(error)")
                    } else {
                        print("Removed message \(messageID) from thread \(threadName)")
                    }
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
