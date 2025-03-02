import SwiftUI

struct ChangelogEntry: Identifiable {
    var id: String { version }
    let version: String
    let date: String
    let changes: [String]
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Version \(currentVersion.version)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(currentVersion.date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(currentVersion.changes, id: \.self) { change in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(change)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    if !history.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Version \(entry.version)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text(entry.date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(entry.changes, id: \.self) { change in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                                .foregroundColor(.secondary)
                                            Text(change)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            
                            if index < history.count - 1 {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Release Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
