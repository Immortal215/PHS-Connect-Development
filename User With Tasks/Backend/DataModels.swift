import SwiftUI

struct Club: Codable, Equatable, Hashable {
    var leaders: [String]  // UI roster projection; authoritative records live in clubMemberships
    var members: [String]  // UI roster projection; authoritative records live in clubMemberships
    var announcements: [String: Announcements]?  // announcements details
    var description: String  // short description
    var name: String
    var normalMeetingTime: String?
    var schoologyCode: String  // schoology code is stored as "xxxx-xxxx-xxxxx (Group)"  inside the parentheseis itll either be Group or Course based on where it is, check refrences in createClubView and elsewhere to see how it is deciphered
    var genres: [String]?
    var clubPhoto: String?
    var abstract: String  // club abstract
    var pendingMemberRequests: Set<String>?  // UserID: emails
    private(set) var clubID: String  // private so it does not get changed outside
    var location: String  // leader inputted location like "room 135"
    var locationInSchoolCoordinates: [Double]?  // 0 is x and 1 is y
    var instagram: String?  // Instagram link
    var clubColor: String?  // color
    var requestNeeded: Bool?
    var chatIDs: [String]?  // chatID's for caching stuff
    var chatEnabled: Bool?
    var lastUpdated: Double?  // timestamp from 1970 and ALWAYS UPDATE THIS WHENEVER UPDATING A FUNCTION
    var photos: [String]? // (Store in firebase storage!) 
    
    struct Announcements: Codable, Equatable, Hashable {
        var date: String
        var title: String
        var body: String
        var writer: String
        var clubID: String
        var peopleSeen: [String]?
        var link: String?
        var linkText: String?
    }

    struct MeetingTime: Codable, Equatable, Hashable, Sendable {
        var meetingID: String?
        var clubID: String
        var startTime: String
        var endTime: String
        var title: String
        var description: String?
        var location: String?
        var fullDay: Bool?
        var visibleByArray: [String]?  // array of emails that can see this meeting time, if you choose only leaders, it will add all leaders emails. If you choose only certain people then it will be them + leaders.
        var seriesID: String?
        var recurrenceIntervalWeeks: Int?
        var recurrenceEndDate: String?
        var startUtc: Double?
        var endUtc: Double?
        var startDate: String?
        var endDateExclusive: String?
        var timeZone: String?
        var visibility: MeetingVisibility?
        var createdAt: Double?
        var updatedAt: Double?
        var revision: Int?
        var cancelled: Bool?
        var cancelledAt: Double?

        struct MeetingVisibility: Codable, Equatable, Hashable, Sendable {
            var mode: String
            var uids: [String: Bool]?
        }

        mutating func setDates(start: Date, end: Date, allDay: Bool) {
            startTime = stringFromDate(start)
            endTime = stringFromDate(end)
            fullDay = allDay
            if allDay {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "America/Chicago")!
                startDate = SharedDateFormatter.chicagoDateOnly.string(from: start)
                endDateExclusive = calendar.date(byAdding: .day, value: 1, to: end)
                    .map { SharedDateFormatter.chicagoDateOnly.string(from: $0) }
                startUtc = nil
                endUtc = nil
            } else {
                startUtc = start.timeIntervalSince1970
                endUtc = end.timeIntervalSince1970
                startDate = nil
                endDateExclusive = nil
            }
        }
    }

    mutating func setClubID(_ newID: String) {  // here so people dont just willy nilly change the clubID
        clubID = newID
    }

}

extension Club {
    private enum CodingKeys: String, CodingKey {
        case leaders, members, announcements, description, name, normalMeetingTime
        case schoologyCode, genres, clubPhoto, abstract, pendingMemberRequests, clubID
        case location, locationInSchoolCoordinates, instagram, clubColor, requestNeeded
        case chatIDs, chatEnabled, lastUpdated, photos
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        leaders = try values.decodeIfPresent([String].self, forKey: .leaders) ?? []
        members = try values.decodeIfPresent([String].self, forKey: .members) ?? []
        announcements = try values.decodeIfPresent([String: Announcements].self, forKey: .announcements)
        description = try values.decode(String.self, forKey: .description)
        name = try values.decode(String.self, forKey: .name)
        normalMeetingTime = try values.decodeIfPresent(String.self, forKey: .normalMeetingTime)
        schoologyCode = try values.decode(String.self, forKey: .schoologyCode)
        genres = try values.decodeIfPresent([String].self, forKey: .genres)
        clubPhoto = try values.decodeIfPresent(String.self, forKey: .clubPhoto)
        abstract = try values.decode(String.self, forKey: .abstract)
        pendingMemberRequests = try values.decodeIfPresent(Set<String>.self, forKey: .pendingMemberRequests)
        clubID = try values.decode(String.self, forKey: .clubID)
        location = try values.decode(String.self, forKey: .location)
        locationInSchoolCoordinates = try values.decodeIfPresent([Double].self, forKey: .locationInSchoolCoordinates)
        instagram = try values.decodeIfPresent(String.self, forKey: .instagram)
        clubColor = try values.decodeIfPresent(String.self, forKey: .clubColor)
        requestNeeded = try values.decodeIfPresent(Bool.self, forKey: .requestNeeded)
        chatIDs = try values.decodeIfPresent([String].self, forKey: .chatIDs)
        chatEnabled = try values.decodeIfPresent(Bool.self, forKey: .chatEnabled)
        lastUpdated = try values.decodeIfPresent(Double.self, forKey: .lastUpdated)
        photos = try values.decodeIfPresent([String].self, forKey: .photos)
    }

}

struct ClubMembershipRecord: Codable, Equatable, Sendable {
    let role: String // "member" or "leader"
    let email: String?
    let accessRevision: Double?
}

struct JoinRequestRecord: Codable, Sendable {
    var email: String?
}

struct ClubAccessEnvelope: Codable, Sendable {
    var ownRequest: JoinRequestRecord?
    var memberships: [String: ClubMembershipRecord]?
    var requests: [String: JoinRequestRecord]?
}

struct Chat: Codable, Equatable, Hashable {
    private(set) var chatID: String  // chatId of the chat // private so it does not get changed outside
    var clubID: String  // clubId that the chat is associated with
    var messages: [ChatMessage]?  // array of Chat.ChatMessage
    var pinned: [String]?  // messageID's

    struct ChatMessage: Codable, Equatable, Hashable {
        struct Poll: Codable, Equatable, Hashable {
            struct Option: Codable, Equatable, Hashable {
                var text: String
                var order: Int
            }

            var options: [String: Option]
            var votes: [String: String]?
        }

        private(set) var messageID: String  // messageId
        var message: String  // message (Only string content)
        var sender: String  // userID
        var date: Double  // use Date().timeIntervalSince1970

        var threadName: String?  // name of thread, by defualt will go to general thread, else go to the name of the new thread
        var reactions: [String: [String]]?  // emoji : [userIDs]
        var lastUpdated: Double?  // Date().timeIntervalSince1970 for when updated

        var replyTo: String?  // messageID of replying to message

        var attachmentURL: String?
        var systemGenerated: Bool?  // true if it’s a system-generated message like "John joined the club!"
        var flagged: Bool?

        var poll: Poll? = nil

        mutating func setMessageID(_ newID: String) {  // here so people dont just willy nilly change the messageID
            messageID = newID
        }
    }
}

struct Personal: Codable, Equatable, Hashable {  // individual user info
    private(set) var userID: String
    var favoritedClubs: [String]  // clubIDs
    var userEmail: String
    var userImage: String
    var userName: String
    var chatNotifStyles: [String: ChatNotifStyle]?  // [chatID : mute style] array of chat mute style for every chat - "all" : every message will notify, "thread" : each thread is different and chosen in threadNotifCustomization and by default
    var mutedThreadsByChat: [String: [String]]?  // [chatID : [thread names]], if in this then it will not notify you for that thread

    enum ChatNotifStyle: String, Codable {
        case all,  // every message will notify
            thread,  // by thread
            none,  // not added yet
            mentions  // not added yet
    }
}
