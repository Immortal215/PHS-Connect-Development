import SwiftUI

struct Change: Identifiable {
    let id = UUID()
    let title: String
    let notes: [String]?
}

struct ChangelogEntry: Identifiable {
    var id: String { version }
    let version: String
    let date: String
    let changes: [Change]
}

class ChangelogViewModel: ObservableObject {
    @Published var currentVersion: ChangelogEntry
    @Published var history: [ChangelogEntry]

    init() {
        self.currentVersion = ChangelogData.currentVersion
        self.history = ChangelogData.history
    }
}

struct ChangelogSheetView: View {
    let currentVersion: ChangelogEntry
    let history: [ChangelogEntry]
    @Environment(\.dismiss) var dismiss
    @State var versionNumToSee: String?
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        changelogSection(for: currentVersion, isCurrentVersion: true)
                        
                        if !history.isEmpty {
                            RoundedRectangle(cornerRadius: 15)
                                .frame(height: 5)
                                .padding(.vertical, 8)
                                .foregroundStyle(.cyan)
                                .shadow(color: .cyan, radius: 3)
                                .id(history[0].version)
                            
                            ForEach(history.indices, id: \ .self) { index in
                                changelogSection(for: history[index], isCurrentVersion: false)
                                
                                if index < history.count - 1 {
                                    Divider()
                                        .padding(.vertical, 8)
                                        .id(history[index + 1].version)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .id(currentVersion.version)
                }
                .onChange(of: versionNumToSee) {
                    proxy.scrollTo(versionNumToSee, anchor: .top)
                }
                .navigationTitle("Release Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu("\(versionNumToSee ?? "Jump to version")") {
                            Picker("", selection: $versionNumToSee) {
                                Text("Version \(currentVersion.version)")
                                    .tag(currentVersion.version)
                                
                                ForEach(history.indices, id: \.self) { i in
                                    Text("Version \(history[i].version)")
                                        .tag(history[i].version)
                                }
                            }
                            //.labelsHidden()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func changelogSection(for entry: ChangelogEntry, isCurrentVersion: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Version \(entry.version)")
                .font(isCurrentVersion ? .title2 : .title3)
                .fontWeight(isCurrentVersion ? .black : .bold)
                .foregroundStyle(isCurrentVersion ? .green : .blue)
            Text(entry.date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.changes) { change in
                    if let notes = change.notes, !notes.isEmpty {
                        DisclosureGroup {
                            VStack(alignment: .leading) {
                                ForEach(notes, id: \ .self) { note in
                                    HStack(alignment: .top) {
                                        Image(systemName: "arrow.turn.down.right")
                                        
                                        Text(note)
                                            .multilineTextAlignment(.leading)
                                            .offset(y: -2)
                                        Spacer()
                                    }
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    
                                }
                            }
                            .padding(.leading, 24)
                        } label: {
                            changeTitleView(title: change.title)

                        }
                    } else {
                        changeTitleView(title: change.title)

                    }
                }
            }
            .padding(.top, 4)
            .foregroundStyle(isCurrentVersion ? .green : .blue)
            .tint(isCurrentVersion ? .green : .blue)

        }
    }
    
    func changeTitleView(title: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(title)
                .multilineTextAlignment(.leading)
                .font(.callout)
        }
    }
}
