import Combine
import Foundation

struct DrawingBoardDocument: Codable, Equatable {
    static let currentSchemaVersion = 3

    var schemaVersion = currentSchemaVersion
    var lists: [DrawingBoardList]
}

struct DrawingBoardList: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var tasks: [DrawingBoardTask]

    init(id: UUID = UUID(), name: String, tasks: [DrawingBoardTask] = []) {
        self.id = id
        self.name = name
        self.tasks = tasks
    }

    var names: [String] {
        tasks.map(\.title)
    }

    var subjects: [String] {
        tasks.map { $0.subject ?? "" }
    }

    var taskDescriptions: [String] {
        tasks.map { $0.details ?? "" }
    }

    var createdDateTexts: [String] {
        tasks.map(\.createdDateText)
    }

    var dueDates: [Date] {
        tasks.map(\.dueDate)
    }

    var subjectExpandedStates: [Bool] {
        tasks.map(\.isSubjectExpanded)
    }

    var descriptionExpandedStates: [Bool] {
        tasks.map(\.isDescriptionExpanded)
    }
}

struct DrawingBoardTask: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var subject: String?
    var details: String?
    var createdDateText: String
    var dueDate: Date
    var isSubjectExpanded: Bool
    var isDescriptionExpanded: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        subject: String? = nil,
        details: String? = nil,
        createdDateText: String = "",
        dueDate: Date,
        isSubjectExpanded: Bool = true,
        isDescriptionExpanded: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subject = Self.optionalText(subject)
        self.details = Self.optionalText(details)
        self.createdDateText = createdDateText
        self.dueDate = dueDate
        self.isSubjectExpanded = isSubjectExpanded
        self.isDescriptionExpanded = isDescriptionExpanded
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subject
        case details
        case createdDateText
        case dueDate
        case isSubjectExpanded
        case isDescriptionExpanded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subject = Self.optionalText(
            try container.decodeIfPresent(String.self, forKey: .subject)
        )
        details = Self.optionalText(
            try container.decodeIfPresent(String.self, forKey: .details)
        )
        createdDateText = try container.decodeIfPresent(
            String.self,
            forKey: .createdDateText
        ) ?? ""
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
            ?? Date()
        isSubjectExpanded = try container.decodeIfPresent(
            Bool.self,
            forKey: .isSubjectExpanded
        ) ?? true
        isDescriptionExpanded = try container.decodeIfPresent(
            Bool.self,
            forKey: .isDescriptionExpanded
        ) ?? true
    }

    static func optionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Enter new value" else {
            return nil
        }
        return value
    }
}

@MainActor
final class DrawingBoardStore: ObservableObject {
    @Published private(set) var lists: [DrawingBoardList]

    let dataURL: URL
    let backupURL: URL

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        directoryURL: URL? = nil
    ) {
        let directory = directoryURL ?? fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        dataURL = directory.appendingPathComponent("drawingboard.json")
        backupURL = directory.appendingPathComponent(
            "drawingboard.backup.json"
        )

        if let document = Self.loadDocument(from: dataURL) {
            let needsUpgrade = document.schemaVersion
                < DrawingBoardDocument.currentSchemaVersion
            var loadedLists = Self.normalizedLists(document.lists)
            if needsUpgrade {
                for listIndex in loadedLists.indices {
                    for taskIndex in loadedLists[listIndex].tasks.indices {
                        loadedLists[listIndex].tasks[taskIndex]
                            .isSubjectExpanded = true
                        loadedLists[listIndex].tasks[taskIndex]
                            .isDescriptionExpanded = true
                    }
                }
            }
            lists = loadedLists
            if needsUpgrade {
                save()
            }
            return
        }

        let canWritePrimary = !fileManager.fileExists(atPath: dataURL.path)
            || Self.archiveUnreadableFile(at: dataURL, using: fileManager)

        if let backup = Self.loadDocument(from: backupURL) {
            lists = Self.normalizedLists(backup.lists)
            if canWritePrimary {
                save(createBackup: false)
            }
            return
        }

        lists = Self.migrateLegacyData(from: userDefaults)
        if canWritePrimary {
            save(createBackup: false)
        }
    }

    var listsByName: [String: DrawingBoardList] {
        Dictionary(uniqueKeysWithValues: lists.map { ($0.name, $0) })
    }

    func replaceLists(with listsByName: [String: DrawingBoardList]) {
        let existingOrder = lists.map(\.name)
        var orderedLists = existingOrder.compactMap { listsByName[$0] }
        let existingNames = Set(existingOrder)
        let newLists = listsByName.values
            .filter { !existingNames.contains($0.name) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name)
                    == .orderedAscending
            }
        orderedLists.append(contentsOf: newLists)
        lists = Self.normalizedLists(orderedLists)
        save()
    }

    func replaceTasks(
        in listName: String,
        names: [String],
        subjects: [String],
        descriptions: [String],
        createdDateTexts: [String],
        dueDates: [Date],
        subjectExpandedStates: [Bool],
        descriptionExpandedStates: [Bool]
    ) {
        var updatedLists = listsByName
        var list = updatedLists[listName]
            ?? DrawingBoardList(name: listName)
        let previousTasks = list.tasks
        let count = max(
            names.count,
            subjects.count,
            descriptions.count,
            createdDateTexts.count,
            dueDates.count
        )

        list.tasks = (0..<count).map { index in
            DrawingBoardTask(
                id: previousTasks[safe: index]?.id ?? UUID(),
                title: names[safe: index] ?? "",
                subject: subjects[safe: index],
                details: descriptions[safe: index],
                createdDateText: createdDateTexts[safe: index] ?? "",
                dueDate: dueDates[safe: index] ?? Date(),
                isSubjectExpanded: subjectExpandedStates[safe: index]
                    ?? previousTasks[safe: index]?.isSubjectExpanded
                    ?? true,
                isDescriptionExpanded: descriptionExpandedStates[safe: index]
                    ?? previousTasks[safe: index]?.isDescriptionExpanded
                    ?? true
            )
        }
        updatedLists[listName] = list
        replaceLists(with: updatedLists)
    }

    func appendTask(_ task: DrawingBoardTask, to listName: String) {
        var updatedLists = listsByName
        var list = updatedLists[listName]
            ?? DrawingBoardList(name: listName)
        list.tasks.append(task)
        updatedLists[listName] = list
        replaceLists(with: updatedLists)
    }

    func removeTask(at index: Int, from listName: String) {
        var updatedLists = listsByName
        guard var list = updatedLists[listName],
            list.tasks.indices.contains(index)
        else {
            return
        }

        list.tasks.remove(at: index)
        updatedLists[listName] = list
        replaceLists(with: updatedLists)
    }

    func save(createBackup: Bool = true) {
        do {
            let document = DrawingBoardDocument(lists: lists)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)

            if createBackup,
                let existingDocument = Self.loadDocument(from: dataURL)
            {
                let backupData = try encoder.encode(existingDocument)
                try backupData.write(to: backupURL, options: .atomic)
            }

            try data.write(to: dataURL, options: .atomic)

            guard Self.loadDocument(from: dataURL) == document else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } catch {
            print("Unable to save Drawing Board data: \(error)")
        }
    }

    static func loadDocument(from url: URL) -> DrawingBoardDocument? {
        guard let data = try? Data(contentsOf: url),
            let document = try? JSONDecoder().decode(
                DrawingBoardDocument.self,
                from: data
            ),
            document.schemaVersion <= DrawingBoardDocument.currentSchemaVersion
        else {
            return nil
        }

        return document
    }

    static func normalizedLists(
        _ lists: [DrawingBoardList]
    ) -> [DrawingBoardList] {
        var seenNames: Set<String> = []
        var normalized: [DrawingBoardList] = []

        for var list in lists {
            let trimmedName = list.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !trimmedName.isEmpty, !seenNames.contains(trimmedName) else {
                continue
            }

            list.name = trimmedName
            seenNames.insert(trimmedName)
            normalized.append(list)
        }

        if normalized.isEmpty {
            normalized = [DrawingBoardList(name: "Basic List")]
        } else if !seenNames.contains("Basic List") {
            normalized.insert(DrawingBoardList(name: "Basic List"), at: 0)
        }

        return normalized
    }

    static func migrateLegacyData(
        from userDefaults: UserDefaults
    ) -> [DrawingBoardList] {
        let legacyLists = userDefaults.dictionary(forKey: "DicKey") ?? [:]
        let legacyDueDates =
            userDefaults.dictionary(forKey: "DueDicKey") ?? [:]
        let listNames = Set(legacyLists.keys).union(legacyDueDates.keys)

        let migratedLists = listNames.sorted {
            if $0 == "Basic List" { return true }
            if $1 == "Basic List" { return false }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }.map { listName in
            migrateLegacyList(
                named: listName,
                values: legacyLists[listName],
                dueDates: legacyDueDates[listName]
            )
        }

        return normalizedLists(migratedLists)
    }

    static func migrateLegacyList(
        named name: String,
        values: Any?,
        dueDates: Any?
    ) -> DrawingBoardList {
        let dictionary = values as? [String: Any] ?? [:]
        let names = stringArray(from: dictionary["names"])
        let subjects = stringArray(from: dictionary["subjects"])
        let descriptions = stringArray(from: dictionary["description"])
        let dates = stringArray(from: dictionary["date"])
        let dueDateValues = dateArray(from: dueDates)
        let count = max(
            names.count,
            subjects.count,
            descriptions.count,
            dates.count,
            dueDateValues.count
        )

        var tasks: [DrawingBoardTask] = []
        for index in 0..<count {
            let title = names[safe: index] ?? ""
            let subject = subjects[safe: index]
            let details = descriptions[safe: index]
            let createdDateText = dates[safe: index] ?? ""
            let dueDate = dueDateValues[safe: index] ?? Date()

            let isLegacySentinel = title.isEmpty
                && (subject?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ?? true)
                && (details?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ?? true)
                && createdDateText.isEmpty
                && count == 1
            if isLegacySentinel { continue }

            tasks.append(
                DrawingBoardTask(
                    title: title,
                    subject: subject,
                    details: details,
                    createdDateText: createdDateText,
                    dueDate: dueDate
                )
            )
        }

        return DrawingBoardList(name: name, tasks: tasks)
    }

    static func stringArray(from value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }

        return (value as? [Any])?.compactMap { $0 as? String } ?? []
    }

    static func dateArray(from value: Any?) -> [Date] {
        if let dates = value as? [Date] {
            return dates
        }

        return (value as? [Any])?.compactMap { item in
            if let date = item as? Date { return date }
            if let timestamp = item as? TimeInterval {
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        } ?? []
    }

    static func archiveUnreadableFile(
        at url: URL,
        using fileManager: FileManager
    ) -> Bool {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let archiveURL = url.deletingLastPathComponent().appendingPathComponent(
            "drawingboard.corrupt-\(timestamp).json"
        )

        do {
            try fileManager.moveItem(at: url, to: archiveURL)
            return true
        } catch {
            print("Unable to archive unreadable Drawing Board data: \(error)")
            return false
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
