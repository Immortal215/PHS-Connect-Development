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
            dropper(title: "Added Club!", subtitle: "", icon: UIImage(systemName: "externaldrive.fill.badge.plus"))
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
                    dropper(title: "Join Request Left!", subtitle: "", icon: nil)
                }
            }
        } else {
            print("Error: Email not found in pending requests.")
        }
    }
}
