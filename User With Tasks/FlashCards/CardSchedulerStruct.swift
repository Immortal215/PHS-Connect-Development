import SwiftUI

struct Scheduler {
    static func today() -> Date { Date() }
    
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: a)
        let end = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    static func addDays(_ d: Date, _ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: d) ?? d
    }
    
    static func remainingDays(deck: Deck) -> Int {
        let end = addDays(deck.startDate, deck.targetDays)
        return max(0, daysBetween(today(), end))
    }
    
    static func nextInterval(current: Int, response: Response, remaining: Int) -> Int {
        let rem = max(1, remaining)
        switch response {
        case .dontKnow:
            return 1
        case .partial:
            let base = max(2, Int(Double(max(1, current)) * 1.2))
            return min(base, max(2, Int(Double(rem) * 0.2)))
        case .know:
            if current <= 0 {
                return max(3, min(7, Int(Double(rem) * 0.5)))
            } else {
                let grown = Int(Double(current) * 2.5)
                return max(3, min(grown, rem))
            }
        }
    }
    
    static func schedule(card: inout Card, in deck: Deck, response: Response) {
        let remaining = remainingDays(deck: deck)
        let next = nextInterval(current: card.intervalDays, response: response, remaining: remaining)
        card.intervalDays = next
        card.due = addDays(today(), next)
        
        switch response {
        case .dontKnow:
            card.ease = max(1.3, card.ease - 0.15)
            card.lapses += 1
        case .partial:
            card.ease = max(1.4, card.ease - 0.05)
        case .know:
            card.ease = min(2.8, card.ease + 0.05)
        }
    }
}

