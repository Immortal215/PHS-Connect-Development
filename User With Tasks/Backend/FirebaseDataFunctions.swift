import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

func addClub(club: Club) {
    let refrence = Database.database().reference()
    let clubRefrence = refrence.child("clubs").child(club.clubID)
    
    do {
        let data = try JSONEncoder().encode(club)
        if let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            clubRefrence.setValue(dictionary)
            //            dropper(title: "Added Club!", subtitle: "", icon: UIImage(systemName: "externaldrive.fill.badge.plus"))
        }
    } catch {
        print("Error encoding club data: \(error)")
    }
}

func fetchClubs(completion: @escaping ([Club]) -> Void) {
    let refrence = Database.database().reference().child("clubs")
    
    refrence.observeSingleEvent(of: .value) { snapshot in
        var clubs: [Club] = []
        
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let value = snap.value as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: value),
               let club = try? JSONDecoder().decode(Club.self, from: jsonData) {
                clubs.append(club)
            }
        }
        
        completion(clubs)
    }
}

func fetchClub(withId clubId: String, completion: @escaping (Club?) -> Void) {
    let reference = Database.database().reference().child("clubs").child(clubId)
    
    reference.observeSingleEvent(of: .value) { snapshot in
        guard let value = snapshot.value as? [String: Any],
              let jsonData = try? JSONSerialization.data(withJSONObject: value),
              let club = try? JSONDecoder().decode(Club.self, from: jsonData) else {
            completion(nil)
            return
        }
        
        completion(club)
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
    
    // Start from index 1
    for clubID in clubIDs {
        group.enter() // Enter the group for each async call
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
        }
    } catch {
        print("Error encoding club data: \(error)")
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

// the below functions are needed to allow normal members to remove themselves from clubs

//func addMemberToClub(clubID: String, memberEmail: String) {
//    let databaseRef = Database.database().reference()
//    let clubRef = databaseRef.child("clubs").child(clubID)
//
//    clubRef.child("members").observeSingleEvent(of: .value) { snapshot in
//        var members = snapshot.value as? [String] ?? []
//
//        if members.contains(memberEmail.lowercased()) {
//            print("Error: Member already in the club.")
//            return
//        }
//
//        members.append(memberEmail.lowercased())
//        clubRef.child("members").setValue(members) { error, _ in
//            if let error = error {
//                print("Error adding member: \(error.localizedDescription)")
//            } else {
//                print("Member added successfully.")
//                dropper(title: "Club Left!", subtitle: "", icon: nil)
//
//            }
//        }
//    }
//}

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
                print("Member added to pending requests successfully.")
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
                print("Added coords successfully.")
                dropper(title: "Location Edited Successfully!", subtitle: "", icon: nil)
            }
        }
    }
}

func fetchChatsMetaData(clubIds: [String], completion: @escaping ([Chat]?) -> Void) {
    let ref = Database.database().reference().child("chats")
    var chatsMeta: [Chat] = []
    let group = DispatchGroup()
    
    for clubID in clubIds {
        group.enter()
        
        ref.queryOrdered (byChild: "clubID")
            .queryEqual(toValue: clubID)
            .observeSingleEvent(of: .value) { snapshot in
                
                if let snapDict = snapshot.value as? [String: Any] {
                    for (_, chatData) in snapDict {
                        if var chatDict = chatData as? [String: Any] {
                            chatDict.removeValue(forKey: "messages") // remove to get rid of type mismatch
                            
                            do {
                                let data = try JSONSerialization.data(withJSONObject: chatDict)
                                var chat = try JSONDecoder().decode(Chat.self, from: data)
                                
                                chat.messages = []
                                
                                chatsMeta.append(chat)
                            } catch {
                                print("Error decoding chat metadata: \(error)")
                            }
                        }
                    }
                }
                
                group.leave()
            }
    }
    
    group.notify(queue: .main) {
        completion(chatsMeta.isEmpty ? nil : chatsMeta)
    }
}

func createClubGroupChat(clubId: String, messageTo: String?, completion: @escaping (Chat) -> Void) {
    let ref = Database.database().reference().child("chats")
    let chatID = ref.childByAutoId().key ?? UUID().uuidString
    
    let newChat = Chat(
        chatID: chatID,
        clubID: clubId,
        directMessageTo: messageTo,
        messages: []
    )
    
    guard var chatDict = try? DictionaryEncoder().encode(newChat) else {
        print("Failed to encode chat")
        return
    }
    
    chatDict.removeValue(forKey: "messages") // remove messages
    
    let group = DispatchGroup()
    group.enter()
    
    ref.child(chatID).setValue(chatDict) { error, _ in
        if let error = error {
            print("Failed to create chat: \(error)")
        } else {
            print("Chat created successfully")
        }
        group.leave()
    }
    
    group.notify(queue: .main) {
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
    
    let messageRef: DatabaseReference
    if !messageToSend.messageID.isEmpty && messageToSend.messageID != String() {
        messageRef = messagesRef.child(messageToSend.messageID) // edit existing
    } else {
        messageRef = messagesRef.childByAutoId() // cvreate new
        messageToSend.messageID = messageRef.key ?? "ERROR"
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
        chatRef.child("lastMessage").setValue(messageDict)
        
        completion?(true)
    }
}
