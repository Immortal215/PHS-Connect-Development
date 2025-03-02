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
    @State private var isShowingFullHistory = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Version \(.init(currentVersion.version))")
                    .font(.title2)
                    .bold()
                
                Text(currentVersion.date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(currentVersion.changes, id: \ .self) { change in
                    Text("• \(change)")
                        .padding(.vertical, 2)
                }
                
                Spacer()
                
                Button(action: {
                    isShowingFullHistory.toggle()
                }) {
                    Text("Show More")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.bottom)
                .sheet(isPresented: $isShowingFullHistory) {
                    FullChangelogView(history: history)
                }
            }
            .padding()
            .navigationTitle("Release Notes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct FullChangelogView: View {
    let history: [ChangelogEntry]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(history) { entry in
                Section(header: Text(.init("Version \(entry.version) - \(entry.date)"))) {
                    ForEach(entry.changes, id: \ .self) { change in
                        Text("• \(change)")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("All Updates")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}
