import FirebaseDatabase

func addClub(clubID: String, club: Club) {
    let refrence = Database.database().reference()
    let clubRefrence = refrence.child("clubs").child(clubID)
    
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

func fetchUserFavoriteClubs(userID: String, completion: @escaping ([Club]) -> Void) {
    let reference = Database.database().reference()
    let userClubsRef = reference.child("users").child(userID).child("favoritedClubs")
    let clubsRef = reference.child("clubs")
    
    userClubsRef.observeSingleEvent(of: .value) { snapshot in
        guard let clubIDs = snapshot.value as? [String] else {
            completion([])
            return
        }
        
        var clubs: [Club] = []
        let dispatchGroup = DispatchGroup()
        
        for clubID in clubIDs {
            dispatchGroup.enter()
            
            clubsRef.child(clubID).observeSingleEvent(of: .value) { clubSnapshot in
                if let value = clubSnapshot.value as? [String: Any],
                   let jsonData = try? JSONSerialization.data(withJSONObject: value),
                   let club = try? JSONDecoder().decode(Club.self, from: jsonData) {
                    clubs.append(club)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(clubs)
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
