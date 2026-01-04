import SwiftUI

struct Club: Codable, Equatable, Hashable {
    var leaders: [String] // emails
    var members: [String] // emails
    var announcements: [String : Announcements]? // announcements details
    var meetingTimes: [MeetingTime]? // meeting times details
    var description: String // short description
    var name: String
    var normalMeetingTime: String?
    var schoologyCode: String // schoology code is stored as "xxxx-xxxx-xxxxx (Group)"  inside the parentheseis itll either be Group or Course based on where it is, check refrences in createClubView and elsewhere to see how it is deciphered
    var genres: [String]?
    var clubPhoto: String?
    var abstract: String // club abstract
    var pendingMemberRequests: Set<String>? // UserID: emails
    private(set) var clubID: String  // private so it does not get changed outside
    var location: String // leader inputted location like "room 135"
    var locationInSchoolCoordinates : [Double]? // 0 is x and 1 is y
    var instagram: String? // Instagram link
    var clubColor: String? // color
    var requestNeeded: Bool?
    var chatIDs: [String]? // chatID's for caching stuff
    var lastUpdated: Double? // timestamp from 1970 and ALWAYS UPDATE THIS WHENEVER UPDATING A FUNCTION
    var leadersUIDs : [String]? // add implementation later 
    var membersUIDs : [String]?
    
    struct Announcements: Codable, Equatable, Hashable { // move this out / use the schoology integration cause this uses too much data
        var date: String
        var title: String
        var body: String
        var writer: String
        var clubID: String
        var peopleSeen: [String]?
        var link: String?
        var linkText: String?
    }
    
    struct MeetingTime: Codable, Equatable, Hashable { // move this out / use the schoology integration cause this uses too much data
        var clubID: String
        var startTime: String
        var endTime: String
        var title: String
        var description: String?
        var location: String?
        var fullDay: Bool? // need to add code for
        var visibleByArray: [String]? // array of emails that can see this meeting time, if you choose only leaders, it will add all leaders emails. If you choose only certain people then it will be them + leaders.
    }
    
    mutating func setClubID(_ newID: String) { // here so people dont just willy nilly change the clubID
        clubID = newID
    }

}

struct Chat: Codable, Equatable, Hashable {
    private(set) var chatID : String // chatId of the chat // private so it does not get changed outside
    var clubID: String // clubId that the chat is associated with
    var directMessageTo: String? // leader userID
    var messages: [ChatMessage]? // array of Chat.ChatMessage
    var typingUsers: [String]? // updated live userID's
    var pinned: [String]? // messageID's
    var lastMessage: ChatMessage?
    
    struct ChatMessage : Codable, Equatable, Hashable {
        private(set) var messageID: String // messageId
        var message : String // message (Only string content)
        var sender : String // userID
        var date : Double // use Date().timeIntervalSince1970
        
        var threadName: String? // name of thread, by defualt will go to general thread, else go to the name of the new thread
        var reactions: [String: [String]]? // emoji : [userIDs]
        var lastUpdated : Double? // Date().timeIntervalSince1970 for when updated
        
        var replyTo : String? // messageID of replying to message
        var edited : Bool? // if edited or not
        
        var attachmentURL: String?
        var attachmentType: String? // "image", "file", "video"
        var systemGenerated: Bool? // true if it’s a system-generated message like "John joined the club!"
        var flagged: Bool?
        
        var mentions: [String]? // userIDs mentioned in the text block (by like @ symbols, need to add this functionality)
        
        mutating func setMessageID(_ newID: String) { // here so people dont just willy nilly change the messageID
            messageID = newID
        }
    }
}

struct Personal: Codable, Equatable, Hashable { // individual user info
    private(set) var userID: String
    var favoritedClubs: [String] // clubIDs
    var userEmail: String
    var userImage: String
    var userName: String
    var fcmToken: String?
}
