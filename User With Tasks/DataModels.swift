import SwiftUI

struct Club: Codable {
    var leaders: [String]
    var members: [String]
    var inviteOnly: Bool
    var announcements: [String: String]?
    var meetingTimes: [String: [String]]?
    var description: String
    var name: String
    var schoologyCode: String
    var genres: [String]?
    var clubPhoto: String?
    var abstract: String
}

struct Personal: Codable {
    var favoritedClubs: [String]
    var subjectPreferences: [String]
    var clubsAPartOf: [String]
}
