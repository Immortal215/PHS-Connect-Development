import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import GoogleSignIn
import GoogleSignInSwift
import Pow
import SwiftUI
import SwiftUIX

private enum ClubSettingsSection: CaseIterable, Hashable {
    case information
    case access
    case leaders
    case members
    case links
    case genres
}

struct CreateClubView: View {
    @State var clubTitle = ""
    @State var clubDesc = ""
    @State var clubAbstract = ""
    @State var schoology = ""
    @State var clubId = ""
    @State var location = ""
    @State var leaders: [String] = []
    @State var members: [String] = []
    @State var genres: [String] = []
    @State var genrePicker = "Non-Competitive"
    @State var clubPhoto = ""
    @State var normalMeet = ""
    @State var addLeaderText = ""
    @State var leaderTextShake = false
    @State var memberDisclosureExpanded = false
    @State var leaderDisclosureExpanded = false
    @State var genreDisclosureExpanded = false
    @State var clubType = "Course"
    @State var selectedLeaders: Set<String> = []
    @State var selectedGenres: Set<String> = []
    @State var requestNeeded: Bool?
    @State var instagram: String?
    @State var clubColor: Color?
    @State var chatEnabled = true
    @State private var didLoadForm = false
    @State private var didCommit = false
    @State private var showMembersEditor = false
    @State private var expandedSections = Set(ClubSettingsSection.allCases)

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onClose: (() -> Void)?
    var onValidationError: (() -> Void)?

    @State var CreatedClub: Club = Club(
        leaders: [],
        members: [],
        description: "",
        name: "",
        schoologyCode: "",
        abstract: "",
        clubID: "",
        location: ""
    )
    @State var clubs: [Club] = []
    var isFormComplete: Bool {
        !clubTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clubDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clubAbstract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !leaders.isEmpty
    }

    var isEditingClub: Bool {
        !clubId.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            Divider()

            ScrollView {
                LazyVGrid(columns: settingsColumns, spacing: 16) {
                    settingsCard(
                        section: .information,
                        title: "Club information",
                        subtitle: "The information students see when they discover this club.",
                        systemImage: "text.alignleft"
                    ) {
                        clubInformationSection
                    }

                    settingsCard(
                        section: .access,
                        title: "Access and appearance",
                        subtitle: "Control how students join and how the club is presented.",
                        systemImage: "slider.horizontal.3"
                    ) {
                        accessSection
                            .padding(.horizontal)
                    }

                    settingsCard(
                        section: .leaders,
                        title: "Leaders",
                        subtitle: "At least one leader email is required.",
                        systemImage: "person.badge.key.fill",
                        showsRequiredIndicator: leaders.isEmpty
                    ) {
                        leaderSection
                    }

                    settingsCard(
                        section: .members,
                        title: "Members",
                        subtitle: "Manage the students who belong to this club on a separate page.",
                        systemImage: "person.2.fill"
                    ) {
                        memberSection
                    }

                    settingsCard(
                        section: .links,
                        title: "Links and schedule",
                        subtitle: "Optional details that help students find and follow the club.",
                        systemImage: "link"
                    ) {
                        detailsSection
                    }

                    settingsCard(
                        section: .genres,
                        title: "Genres",
                        subtitle: "Choose up to five tags to improve club discovery.",
                        systemImage: "tag.fill"
                    ) {
                        genreSection
                    }
                }
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalSizeClass == .compact ? 16 : 28)
                .padding(.vertical, 20)
            }
        }
        .background(Color.systemGray6.opacity(0.55))
        .textFieldStyle(.roundedBorder)
        .onAppear(perform: loadClub)
        .onDisappear(perform: handleDismissal)
        .sheet(isPresented: $showMembersEditor) {
            ClubMembersEditorView(members: $members)
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
        }
    }

    var settingsColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(), alignment: .top)]
        }

        return [
            GridItem(.flexible(), spacing: 16, alignment: .top),
            GridItem(.flexible(), spacing: 16, alignment: .top),
        ]
    }

    var editorHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(0.68),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: isEditingClub ? "gearshape.fill" : "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(isEditingClub ? "Club settings" : "Create a club")
                    .font(.title2.bold())

                Text(
                    isEditingClub
                        ? "Update \(clubTitle.isEmpty ? "this club" : clubTitle)"
                        : "Add the details students need to find and join"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            Label(
                isFormComplete ? "Ready" : "Missing information",
                systemImage: isFormComplete
                    ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
            .font(.caption.bold())
            .foregroundStyle(isFormComplete ? .green : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                (isFormComplete ? Color.green : Color.red).opacity(0.12),
                in: Capsule()
            )

            Button(action: commitClub) {
                Label(
                    isEditingClub ? "Edit Club" : "Create Club",
                    systemImage: isEditingClub ? "pencil" : "plus"
                )
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    isFormComplete
                        ? (isEditingClub ? Color.blue : Color.green)
                        : Color.gray,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!isFormComplete)
        }
        .padding(20)
        .background(Color.systemBackground)
    }

    @ViewBuilder
    var clubInformationSection: some View {
        settingsField(
            "Club name",
            placeholder: "Club Name",
            text: $clubTitle,
            required: true
        )

        settingsField(
            "Short description",
            placeholder: "A quick summary of the club",
            text: $clubDesc,
            required: true
        )

        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Club abstract", isMissing: clubAbstract.isEmpty)

            TextEditor(text: $clubAbstract)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 130)
                .background(
                    Color.systemGray6,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            clubAbstract.isEmpty
                                ? Color.red.opacity(0.65)
                                : Color.secondary.opacity(0.22),
                            lineWidth: 1
                        )
                }
        }

        settingsField(
            "Location",
            placeholder: "Room or meeting location",
            text: $location,
            required: true
        )
    }

    @ViewBuilder
    var accessSection: some View {
        Toggle(
            isOn: Binding(
                get: { requestNeeded ?? false },
                set: { requestNeeded = $0 ? true : nil }
            )
        ) {
            settingDescription(
                title: "Join request required",
                detail: "Leaders approve students before they become members.",
                systemImage: "person.crop.circle.badge.checkmark"
            )
        }
        .tint(.blue)

        Divider()

        Toggle(isOn: $chatEnabled) {
            settingDescription(
                title: "Club chat",
                detail: chatEnabled
                    ? "Chat is enabled for all club members."
                    : "Chat is disabled for all club members.",
                systemImage: chatEnabled
                    ? "bubble.left.and.bubble.right.fill"
                    : "bubble.left.and.bubble.right"
            )
        }
        .tint(.blue)

        Divider()

        HStack {
            settingDescription(
                title: "Club color",
                detail: "Used for accents throughout PHS Connect.",
                systemImage: "paintpalette.fill"
            )

            Spacer()

            ColorPicker(
                "Club color",
                selection: Binding(
                    get: { clubColor ?? Color.gray.opacity(0.3) },
                    set: { clubColor = $0 }
                )
            )
            .labelsHidden()
        }
    }

    @ViewBuilder
    var leaderSection: some View {
        emailEntryRow(
            placeholder: "Add leader email(s)",
            text: $addLeaderText,
            isShaking: leaderTextShake,
            addAction: addLeaderFunc,
            removeAction: {
                leaders.removeAll { selectedLeaders.contains($0) }
                selectedLeaders.removeAll()
            },
            canRemove: !selectedLeaders.isEmpty
        )

        emailChipGrid(
            emails: leaders,
            selection: $selectedLeaders,
            emptyMessage: "Add at least one leader to complete the club."
        )
    }

    @ViewBuilder
    var memberSection: some View {
        Button {
            showMembersEditor = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))

                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.blue)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Members")
                        .font(.subheadline.bold())

                    Text(
                        members.isEmpty
                            ? "No members added"
                            : "\(members.count) member\(members.count == 1 ? "" : "s")"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.systemGray6,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schoology code")
                .font(.subheadline.bold())

            HStack {
                TextField("XXXX-XXXX-XXXXX", text: $schoology)

                if schoology.replacingOccurrences(of: "-", with: "").count > 12 {
                    Picker("Type", selection: $clubType) {
                        Text("Course").tag("Course")
                        Text("Group").tag("Group")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 190)
                }
            }

            Text(
                schoology.replacingOccurrences(of: "-", with: "").count > 12
                    ? "The code will be saved with its Schoology type."
                    : "Leave this blank to display “None.”"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        settingsField(
            "Club photo URL",
            placeholder: "https://…",
            text: $clubPhoto
        )

        settingsField(
            "Normal meeting times",
            placeholder: "For example: Tuesdays after school",
            text: $normalMeet
        )

        VStack(alignment: .leading, spacing: 8) {
            Text("Instagram username")
                .font(.subheadline.bold())

            TextField(
                "username",
                text: Binding(
                    get: { instagram ?? "" },
                    set: { instagram = $0.isEmpty ? nil : $0 }
                )
            )
        }
    }

    @ViewBuilder
    var genreSection: some View {
        HStack {
            Picker("Genre", selection: $genrePicker) {
                Text("Competitive").tag("Competitive")
                Text("Non-Competitive").tag("Non-Competitive")

                Section("Subjects") {
                    Text("Math").tag("Math")
                    Text("Science").tag("Science")
                    Text("Reading").tag("Reading")
                    Text("History").tag("History")
                    Text("Business").tag("Business")
                    Text("Technology").tag("Technology")
                    Text("Art").tag("Art")
                    Text("Fine Arts").tag("Fine Arts")
                    Text("Speaking").tag("Speaking")
                    Text("Health").tag("Health")
                    Text("Law").tag("Law")
                    Text("Engineering").tag("Engineering")
                }

                Section("Descriptors") {
                    Text("Cultural").tag("Cultural")
                    Text("Physical").tag("Physical")
                    Text("Mental Health").tag("Mental Health")
                    Text("Safe Space").tag("Safe Space")
                }
            }

            Button {
                guard genres.count < 5, !genres.contains(genrePicker) else {
                    return
                }
                genres.append(genrePicker)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(genres.count >= 5 || genres.contains(genrePicker))

            if !selectedGenres.isEmpty {
                Button(role: .destructive) {
                    genres.removeAll { selectedGenres.contains($0) }
                    selectedGenres.removeAll()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }

        selectableChipGrid(
            values: genres,
            selection: $selectedGenres,
            emptyMessage: "No genres selected. Non-Competitive will be used by default."
        )

        Text("\(genres.count)/5 genres")
            .font(.caption)
            .foregroundStyle(genres.count >= 5 ? .red : .secondary)
    }

    private func settingsCard<Content: View>(
        section: ClubSettingsSection,
        title: String,
        subtitle: String,
        systemImage: String,
        showsRequiredIndicator: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains(section) },
                set: { isExpanded in
                    withAnimation(.smooth(duration: 0.25)) {
                        if isExpanded {
                            expandedSections.insert(section)
                        } else {
                            expandedSections.remove(section)
                        }
                    }
                }
            )
        ) {
            Divider()
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(.top, 14)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)

                        if showsRequiredIndicator {
                            Text("Required")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    func settingsField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        required: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel(
                title,
                isMissing: required
                    && text.wrappedValue.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
            )

            TextField(placeholder, text: text)
        }
    }

    func requiredLabel(_ title: String, isMissing: Bool) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.subheadline.bold())

            if isMissing {
                Text("Required")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
    }

    func settingDescription(
        title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func emailEntryRow(
        placeholder: String,
        text: Binding<String>,
        isShaking: Bool,
        addAction: @escaping () -> Void,
        removeAction: @escaping () -> Void,
        canRemove: Bool
    ) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .changeEffect(.shake(rate: .fast), value: isShaking)
                .onSubmit(addAction)

            Button(action: addAction) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderedProminent)

            if canRemove {
                Button(role: .destructive, action: removeAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    func emailChipGrid(
        emails: [String],
        selection: Binding<Set<String>>,
        emptyMessage: String
    ) -> some View {
        selectableChipGrid(
            values: emails,
            selection: selection,
            emptyMessage: emptyMessage
        )
    }

    func selectableChipGrid(
        values: [String],
        selection: Binding<Set<String>>,
        emptyMessage: String
    ) -> some View {
        Group {
            if values.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 8)
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(values, id: \.self) { value in
                        let isSelected = selection.wrappedValue.contains(value)

                        Button {
                            if isSelected {
                                selection.wrappedValue.remove(value)
                            } else {
                                selection.wrappedValue.insert(value)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(
                                    systemName: isSelected
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                Text(value)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .font(.caption)
                            .foregroundStyle(isSelected ? .red : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                (isSelected ? Color.red : Color.systemGray6)
                                    .opacity(isSelected ? 0.12 : 1),
                                in: RoundedRectangle(
                                    cornerRadius: 9,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 9,
                                    style: .continuous
                                )
                                .stroke(
                                    isSelected
                                        ? Color.red.opacity(0.55)
                                        : Color.secondary.opacity(0.12),
                                    lineWidth: 1
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    func loadClub() {
        guard !didLoadForm else { return }

        leaders = CreatedClub.leaders.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        members = CreatedClub.members.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        clubId = CreatedClub.clubID
        clubTitle = CreatedClub.name
        clubDesc = CreatedClub.description
        clubAbstract = CreatedClub.abstract
        schoology = CreatedClub.schoologyCode
        location = CreatedClub.location
        genres = CreatedClub.genres ?? []
        instagram = CreatedClub.instagram
        clubColor = Color(
            hexadecimal: CreatedClub.clubColor
                ?? colorFromClub(club: CreatedClub).toHexString()
        )
        clubPhoto = CreatedClub.clubPhoto ?? ""
        normalMeet = CreatedClub.normalMeetingTime ?? ""
        requestNeeded = CreatedClub.requestNeeded
        chatEnabled = CreatedClub.chatEnabled ?? true

        if schoology != "" {
            clubType = schoology.contains("Group") ? "Group" : "Course"
        }
        schoology = schoology
            .replacingOccurrences(of: " (Course)", with: "")
            .replacingOccurrences(of: " (Group)", with: "")

        didLoadForm = true
    }

    func commitClub() {
        guard isFormComplete else { return }

        didCommit = true
        saveClub()
        onClose?()
    }

    func handleDismissal() {
        guard didLoadForm, !didCommit else { return }

        guard isFormComplete else {
            onValidationError?()
            return
        }

        guard isEditingClub else {
            return
        }

        didCommit = true
        saveClub()
        onClose?()
    }

    func saveClub() {
        if clubId.isEmpty {
            let lastDigit =
                clubs
                .compactMap {
                    Int(
                        $0.clubID.replacingOccurrences(
                            of: "clubID",
                            with: ""
                        )
                    )
                }
                .max() ?? 0
            CreatedClub.setClubID("clubID\(lastDigit + 1)")
        } else {
            CreatedClub.setClubID(clubId)
        }

        let compactSchoology = schoology.replacingOccurrences(of: "-", with: "")
        if compactSchoology.count > 12 {
            CreatedClub.schoologyCode =
                String(compactSchoology.prefix(4)) + "-"
                + String(compactSchoology.dropFirst(4).prefix(4)) + "-"
                + String(compactSchoology.dropFirst(8).prefix(5))
                + " (\(clubType))"
        } else {
            CreatedClub.schoologyCode = "None"
        }

        CreatedClub.name = clubTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        CreatedClub.description = clubDesc.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        CreatedClub.abstract = clubAbstract.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        CreatedClub.location = location.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        CreatedClub.leaders = leaders
        CreatedClub.members = members.isEmpty ? [leaders[0]] : members
        CreatedClub.genres = genres.isEmpty ? ["Non-Competitive"] : genres
        CreatedClub.requestNeeded = requestNeeded
        CreatedClub.instagram = instagram
        CreatedClub.clubColor = clubColor?.toHexString()
        CreatedClub.clubPhoto = clubPhoto.isEmpty ? nil : clubPhoto
        CreatedClub.normalMeetingTime = normalMeet.isEmpty ? nil : normalMeet
        CreatedClub.chatEnabled = chatEnabled

        addClub(club: CreatedClub)
    }



    func addLeaderFunc() {
        addLeaderText = addLeaderText.replacingOccurrences(of: " ", with: "")
        if (addLeaderText.contains("d214.org")
            || addLeaderText.contains("gmail.com"))
            && leaders.contains(addLeaderText) == false
        {
            if addLeaderText.contains("<") && addLeaderText.contains(">") {

                // below code splits emails if it looks like this :
                // Pryncess Butler <pbutler5545@stu.d214.org>, Destani Cross <dcross6555@stu.d214.org>, Makaylah Mosby <mmosby5290@stu.d214.org>

                var splitLeaders: [Substring] = []

                for entry in addLeaderText.split(separator: ",") {
                    let trimmedEntry = entry.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    if let start = trimmedEntry.firstIndex(of: "<"),
                        let end = trimmedEntry.firstIndex(of: ">")
                    {
                        let email = String(
                            trimmedEntry[trimmedEntry.index(after: start)..<end]
                        )
                        splitLeaders.append(Substring(email))
                    }
                }

                addLeaderHelpperFunc(splitLeaders: splitLeaders)

            } else if addLeaderText.contains(",") {
                addLeaderHelpperFunc(
                    splitLeaders: addLeaderText.split(separator: ",")
                )

            } else if addLeaderText.contains("/") {
                addLeaderHelpperFunc(
                    splitLeaders: addLeaderText.split(separator: "/")
                )

            } else if addLeaderText.contains(";") {
                addLeaderHelpperFunc(
                    splitLeaders: addLeaderText.split(separator: ";")
                )

            } else if addLeaderText.contains("-") {
                addLeaderHelpperFunc(
                    splitLeaders: addLeaderText.split(separator: "-")
                )
            } else {
                leaders.append(addLeaderText.lowercased())
                addLeaderText = ""
            }
        } else {
            leaderTextShake.toggle()
            dropper(
                title: "Enter a correct email!",
                subtitle: "Use the d214.org ending!",
                icon: UIImage(systemName: "trash")
            )
        }
    }

    func addLeaderHelpperFunc(splitLeaders: [Substring]) {
        for i in splitLeaders {
            if leaders.contains(String(i)) == false {
                if leaders.count < 6 {
                    leaders.append(String(i).lowercased())
                } else {
                    dropper(
                        title: "Too Many Leaders",
                        subtitle: "Max 6",
                        icon: nil
                    )
                    break
                }
            }
        }
        addLeaderText = ""
    }

}

struct ClubMembersEditorView: View {
    @Binding var members: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var emailDraft = ""
    @State private var feedbackMessage = ""
    @State private var feedbackIsError = false

    var filteredMembers: [String] {
        members
            .filter {
                searchText.isEmpty
                    || $0.localizedCaseInsensitiveContains(searchText)
            }
            .sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    memberSummary
                    bulkAddCard
                    memberListCard
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            .background(Color.systemGray6.opacity(0.55))
            .navigationTitle("Club Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    var memberSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.12))

                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Manage Members")
                    .font(.headline)

                Text(
                    "\(members.count) member\(members.count == 1 ? "" : "s") in this club"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    var bulkAddCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add Members", systemImage: "person.badge.plus")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $emailDraft)
                    .frame(minHeight: 92)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .background(
                        Color.systemGray6,
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                if emailDraft.isEmpty {
                    Text("Paste one or more email addresses")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }

            Text("Separate multiple emails with commas, semicolons, or new lines.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !feedbackMessage.isEmpty {
                Label(
                    feedbackMessage,
                    systemImage: feedbackIsError
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(feedbackIsError ? .red : .green)
            }

            Button(action: addMembers) {
                Label("Add Emails", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                emailDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        }
        .padding(16)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    var memberListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Current Members", systemImage: "person.3.fill")
                    .font(.headline)

                Spacer()

                Text("\(filteredMembers.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search member emails", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.systemGray6,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )

            if filteredMembers.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Members" : "No Results",
                    systemImage: searchText.isEmpty
                        ? "person.2.slash" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "Add member emails above."
                            : "No member email matches your search."
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredMembers, id: \.self) { member in
                        memberRow(member)

                        if member != filteredMembers.last {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    func memberRow(_ member: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.1), in: Circle())

            Text(member)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button(role: .destructive) {
                withAnimation {
                    members.removeAll {
                        $0.caseInsensitiveCompare(member) == .orderedSame
                    }
                }
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(member)")
        }
        .padding(.vertical, 8)
    }

    func addMembers() {
        let entries = emailDraft.split(omittingEmptySubsequences: true) {
            $0 == "," || $0 == ";" || $0.isNewline
        }
        let emails = entries.map(extractEmail)
        let validEmails = emails.filter(isAllowedMemberEmail)
        let invalidCount = emails.count - validEmails.count
        var existingEmails = Set(members.map { $0.lowercased() })
        var addedEmails: [String] = []

        for email in validEmails where !existingEmails.contains(email) {
            existingEmails.insert(email)
            addedEmails.append(email)
        }

        members.append(contentsOf: addedEmails)
        members.sort {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if !addedEmails.isEmpty {
            emailDraft = ""
            feedbackIsError = invalidCount > 0
            feedbackMessage = "Added \(addedEmails.count) member\(addedEmails.count == 1 ? "" : "s")"
                + (invalidCount > 0 ? "; skipped \(invalidCount) invalid email\(invalidCount == 1 ? "" : "s")." : ".")
        } else if invalidCount > 0 {
            feedbackIsError = true
            feedbackMessage = "Enter a d214.org or gmail.com email address."
        } else {
            feedbackIsError = true
            feedbackMessage = "Those members are already in this club."
        }
    }

    func extractEmail(from entry: Substring) -> String {
        let value = String(entry).trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = value.firstIndex(of: "<"),
            let end = value[start...].firstIndex(of: ">"),
            start < end
        {
            return String(value[value.index(after: start)..<end])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        return value.replacingOccurrences(of: " ", with: "").lowercased()
    }

    func isAllowedMemberEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1].lowercased()
        return domain == "gmail.com"
            || domain == "d214.org"
            || domain.hasSuffix(".d214.org")
    }
}

struct IncompleteClubInformationBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Club changes discarded")
                    .font(.headline)

                Text("All required club information must be completed before saving.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
            }

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            Color.red,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}
