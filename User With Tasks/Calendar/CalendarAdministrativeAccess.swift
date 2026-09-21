import SwiftUI

struct AdministrativeCalendarAccessRegistry {
    struct Acquisition {
        let id: UUID
        let activatedClub: Bool
    }

    struct Release {
        let clubID: String
        let deactivatedClub: Bool
    }

    private var clubIDByLease: [UUID: String] = [:]
    private var leaseCountByClubID: [String: Int] = [:]

    var clubIDs: Set<String> { Set(leaseCountByClubID.keys) }

    mutating func acquire(clubID: String) -> Acquisition {
        let id = UUID()
        let previousCount = leaseCountByClubID[clubID, default: 0]
        clubIDByLease[id] = clubID
        leaseCountByClubID[clubID] = previousCount + 1
        return Acquisition(id: id, activatedClub: previousCount == 0)
    }

    mutating func release(_ id: UUID) -> Release? {
        guard let clubID = clubIDByLease.removeValue(forKey: id),
              let count = leaseCountByClubID[clubID]
        else { return nil }
        if count > 1 {
            leaseCountByClubID[clubID] = count - 1
            return Release(clubID: clubID, deactivatedClub: false)
        }
        leaseCountByClubID[clubID] = nil
        return Release(clubID: clubID, deactivatedClub: true)
    }

    mutating func removeAll() {
        clubIDByLease.removeAll()
        leaseCountByClubID.removeAll()
    }
}

private struct CalendarAdministrativeAccessModifier: ViewModifier {
    @Environment(CalendarDataStore.self) private var calendarStore
    let clubID: String?
    let enabled: Bool
    @State private var leaseID: UUID?
    @State private var leasedClubID: String?

    func body(content: Content) -> some View {
        content
            .onAppear { updateLease() }
            .onChange(of: clubID) { _, _ in updateLease() }
            .onChange(of: enabled) { _, _ in updateLease() }
            .onDisappear { releaseLease() }
    }

    private func updateLease() {
        let requestedClubID = enabled ? clubID?.nilIfEmpty : nil
        guard requestedClubID != leasedClubID else { return }
        releaseLease()
        guard let requestedClubID else { return }
        leaseID = calendarStore.beginAdministrativeAccess(for: requestedClubID)
        leasedClubID = requestedClubID
    }

    private func releaseLease() {
        if let leaseID { calendarStore.endAdministrativeAccess(leaseID) }
        leaseID = nil
        leasedClubID = nil
    }
}

extension View {
    func calendarAdministrativeAccess(clubID: String?, enabled: Bool) -> some View {
        modifier(CalendarAdministrativeAccessModifier(clubID: clubID, enabled: enabled))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
