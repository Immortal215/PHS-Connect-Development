import SwiftUI

enum Response: String, CaseIterable, Codable {
    case dontKnow
    case partial
    case know
    
    var name: String {
        switch self {
            case .dontKnow : return "Don't know"
            case .partial : return "Partially Known"
            case .know : return "Known"
        }
    }
    
    var color: Color {
        switch self {
        case .dontKnow : return .red
        case .partial : return .orange
        case .know : return .green
        }
    }
}

struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    var front: String
    var back: String
    
    // below is for anki-style stuff
    var intervalDays: Int
    var due: Date
    var ease: Double
    var lapses: Int
    
    // below is for simple know/don't know categories
    var known : Bool? // nil - non category, false - not known, true - known 
}

struct Deck: Identifiable, Codable, Hashable {
    let id: UUID
    var targetDays: Int
    var startDate: Date
    var title: String
    var cards: [Card]
    
    var definitionFront : Bool? = true
    var selected = false
}
