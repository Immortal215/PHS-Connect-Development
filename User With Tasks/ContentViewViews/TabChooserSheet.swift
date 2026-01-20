import SwiftUI

struct TabChooserSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var tabsCache: UserTabPreferences?
    let isGuestUser: Bool

    @State var draft = UserTabPreferences(
        order: AppTab.allCases,
        hidden: []
    )

    var normalized: UserTabPreferences {
        var seen = Set<AppTab>()
        var order: [AppTab] = []

        for t in draft.order where !seen.contains(t) {
            order.append(t)
            seen.insert(t)
        }
        for t in AppTab.allCases where !seen.contains(t) {
            order.append(t)
        }

        let hidden = Set(draft.hidden.filter { AppTab.allCases.contains($0) })
        return UserTabPreferences(order: order, hidden: hidden)
    }

    var visibleTabs: [AppTab] {
        normalized.order.filter { !normalized.hidden.contains($0) }
    }

    var hiddenTabs: [AppTab] {
        normalized.order.filter { normalized.hidden.contains($0) }
    }

    func toggleHidden(_ tab: AppTab) {
        if draft.hidden.contains(tab) {
            draft.hidden.remove(tab)
        } else {
            draft.hidden.insert(tab)
        }
        draft = normalized
    }

    func applyMove(from: IndexSet, to: Int) {
        var vis = visibleTabs
        vis.move(fromOffsets: from, toOffset: to)

        let hid = hiddenTabs
        draft.order = vis + hid
        draft = normalized
    }

    func canToggle(_ tab: AppTab) -> Bool {
        if isGuestUser && tab.loginRequired { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Enabled") {
                    ForEach(visibleTabs, id: \.self) { tab in
                        HStack(alignment: .bottom) {
                            
                            Image(systemName: tab.systemImage)
                            
                            Text(tab.name)
                            
                            if(tab == .settings) {
                                Text("Cannot be removed!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            
                            if (tab == .clubs || tab == .settings)  {
                                Image(systemName: "lock")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !(tab == .settings) {
                                guard canToggle(tab) else { return }
                                toggleHidden(tab)
                            }
                        }
                    }
                    .onMove(perform: applyMove)
                }

                Section("Disabled") {
                    ForEach(hiddenTabs, id: \.self) { tab in
                        HStack {
                            Image(systemName: tab.systemImage)
                                .foregroundStyle(.secondary)
                            Text(tab.name)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard canToggle(tab) else { return }
                            toggleHidden(tab)
                        }
                    }
                }
            }
            .navigationTitle("Customize Tabs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        tabsCache = normalized
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let cache = tabsCache {
                draft = cache
            }
        }
    }
}
