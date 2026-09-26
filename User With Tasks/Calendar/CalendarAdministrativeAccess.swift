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
    @Environment(CalendarDataStore.self) var calendarStore
    let clubIDs: Set<String>
    let enabled: Bool
    let retainsCacheOnDisappear: Bool
    @State var isVisible = false
    @State var leases: [String: UUID] = [:]

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                updateLeases()
            }
            .onChange(of: clubIDs) { _, _ in updateLeases() }
            .onChange(of: enabled) { _, _ in updateLeases() }
            .onDisappear {
                isVisible = false
                updateLeases(preservingCache: retainsCacheOnDisappear && enabled)
            }
    }

    func updateLeases(preservingCache: Bool = false) {
        let requested = isVisible && enabled ? Set(clubIDs.filter { !$0.isEmpty }) : []
        for clubID in Set(leases.keys).subtracting(requested) {
            if let leaseID = leases.removeValue(forKey: clubID) {
                calendarStore.endAdministrativeAccess(leaseID, preserveCache: preservingCache)
            }
        }
        var acquired = false
        for clubID in requested.subtracting(leases.keys).sorted() {
            leases[clubID] = calendarStore.beginAdministrativeAccess(for: clubID)
            acquired = true
        }
        if acquired { calendarStore.restoreCachedAdministrativeMeetings() }
    }
}

extension View {
    func calendarAdministrativeAccess(clubID: String?, enabled: Bool) -> some View {
        calendarAdministrativeAccess(
            clubIDs: clubID.map { Set([$0]) } ?? [], enabled: enabled
        )
    }

    func calendarAdministrativeAccess(
        clubIDs: Set<String>, enabled: Bool, retainsCacheOnDisappear: Bool = false
    ) -> some View {
        modifier(CalendarAdministrativeAccessModifier(
            clubIDs: clubIDs,
            enabled: enabled,
            retainsCacheOnDisappear: retainsCacheOnDisappear
        ))
    }
}
