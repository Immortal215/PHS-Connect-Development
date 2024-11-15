import FirebaseDatabase

func addClub(club: Club) {
    let refrence = Database.database().reference()
    let clubRefrence = refrence.child("clubs").child(club.clubID)
    
    do {
        let data = try JSONEncoder().encode(club)
        if let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            clubRefrence.setValue(dictionary)
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

func addClubToUser(userID: String, clubID: String) {
    let reference = Database.database().reference()
    let userClubReference = reference.child("users").child(userID).child("clubsAPartOf")
    
    userClubReference.observeSingleEvent(of: .value) { snapshot in
        var updatedClubs = snapshot.value as? [String] ?? []
        
        if !updatedClubs.contains(clubID) {
            updatedClubs.append(clubID)
            userClubReference.setValue(updatedClubs)
        }
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

func addAnnouncment(clubID: String, date: String, title: String, body: String) {
    let reference = Database.database().reference()
    let announcementRefrence = reference.child("clubs").child(clubID).child("announcements").child(date)
    
    announcementRefrence.observeSingleEvent(of: .value) { snapshot in
        var announcements = snapshot.value as? [String] ?? []
        
            announcements.append(title)
            announcements.append(body)
            announcementRefrence.setValue(announcements)
        
    }
}
