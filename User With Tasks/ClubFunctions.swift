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
