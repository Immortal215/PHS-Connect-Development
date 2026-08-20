import Pow
import SwiftUI

struct Notebook: View {
    @EnvironmentObject var drawingBoardStore: DrawingBoardStore
    @State var screenWidth = appScreenBounds.width
    @State var screenHeight = appScreenBounds.height

    @AppStorage("completed") var completed = 0

    @AppStorage("selectedTab") var selectedTab = 1
    @AppStorage("currentTab") var currentTab = "Basic List"

    var bigDic: [String: DrawingBoardList] {
        get { drawingBoardStore.listsByName }
        nonmutating set { drawingBoardStore.replaceLists(with: newValue) }
    }

    @State var allSubjects: [String: [String]] = [:]

    @State var subjects: [String] = []

    @State var names: [String] = []

    @State var infoArray: [String] = []

    @State var dates: [String] = []

    @State var dueDates: [Date] = []
    @State var subjectExpandedStates: [Bool] = []
    @State var descriptionExpandedStates: [Bool] = []
    @State var commonSub = ["English", "Math", "Science", "History"]
    @State var createTab = ""
    @State var deleteTabs = ""
    @State var deleteWarning = false
    @State var addWarning = false

    @AppStorage("duedatesetter") var dueDateSetter = "Two Days"
    @AppStorage("dueDater") var dueDater = "07:00"
    @AppStorage("organizedAssignments") var organizedAssignments =
        "Due By Descending (Recent to Oldest)"

    @AppStorage("subjectcolor") var subjectColor: String = "#91E2FD"
    @AppStorage("titlecolor") var titleColor: String = "#E2FFC2"
    @AppStorage("descolor") var descriptionColor: String = "#FFFFFF"
    @AppStorage("emptyClear") var emptyClear = false
    @AppStorage("subjectPicker") var subjectPicker = true

    @State var description = ""
    @State var name = ""
    @State var subject = ""
    @State var date = ""

    @State var showAlert = false
    @State var showDelete = false
    @State var loadedData = false
    @State var caughtUp = false
    @State var showDeleteAllConfirmation = false
    @State var error = false
    @State var boxesFilled = false
    @State var settings = false
    @State var selectDelete: [Bool] = []
    @State var assignmentAnimation = false
    @State var pickerOpen = false
    @State var hasAppeared = false

    func saveCurrentTasks() {
        guard currentTab != "+erder" else { return }
        drawingBoardStore.replaceTasks(
            in: currentTab,
            names: names,
            subjects: subjects,
            descriptions: infoArray,
            createdDateTexts: dates,
            dueDates: dueDates,
            subjectExpandedStates: subjectExpandedStates,
            descriptionExpandedStates: descriptionExpandedStates
        )
    }

    func dueDateForNewTask() -> Date {
        let secondsUntilTime = TimeInterval(
            calculateSecondsUntil(timeString: dueDater)
        )

        switch dueDateSetter {
        case "One Hour": return Date(timeIntervalSinceNow: 3600)
        case "6 Hours": return Date(timeIntervalSinceNow: 21600)
        case "Today": return Date(timeIntervalSinceNow: secondsUntilTime)
        case "One Day":
            return Date(timeIntervalSinceNow: 86401 + secondsUntilTime)
        case "Two Days":
            return Date(timeIntervalSinceNow: 172801 + secondsUntilTime)
        case "Four Days":
            return Date(timeIntervalSinceNow: 345601 + secondsUntilTime)
        case "Five Days":
            return Date(timeIntervalSinceNow: 432001 + secondsUntilTime)
        default: return Date()
        }
    }

    func loadCurrentList() {
        if currentTab == "+erder" || bigDic[currentTab] == nil {
            currentTab = "Basic List"
        }

        guard var list = bigDic[currentTab] else { return }
        switch organizedAssignments {
        case "Due By Descending (Recent to Oldest)":
            list.tasks.sort { $0.dueDate < $1.dueDate }
        case "Due By Ascending (Oldest to Recent)":
            list.tasks.sort { $0.dueDate > $1.dueDate }
        case "Created By Ascending (Oldest to Recent)":
            list.tasks.sort { $0.createdDateText < $1.createdDateText }
        default:
            list.tasks.sort { $0.createdDateText > $1.createdDateText }
        }
        bigDic[currentTab] = list

        names = list.names
        subjects = list.subjects
        infoArray = list.taskDescriptions
        dates = list.createdDateTexts
        dueDates = list.dueDates
        subjectExpandedStates = list.subjectExpandedStates
        descriptionExpandedStates = list.descriptionExpandedStates
        selectDelete = Array(repeating: false, count: list.tasks.count)
        caughtUp = list.tasks.isEmpty

        allSubjects = [:]
        for storedList in drawingBoardStore.lists
        where storedList.name.lowercased().hasSuffix(" list") {
            allSubjects[storedList.name] = storedList.subjects.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }

        if selectedTab == 0 {
            for index in infoArray.indices {
                if infoArray[index] == "Enter new value" {
                    infoArray[index] = ""
                }
                if subjects[index] == "Enter new value" {
                    subjects[index] = ""
                }
            }
            saveCurrentTasks()
        }

        error = false
        loadedData = true
    }

    var body: some View {
        ZStack {

            VStack {
                HStack {
                    Text("Planner")
                        .font(.title)
                        .fontWeight(.semibold)
                        .offset(x: currentTab != "+erder" ? 160 : 0)
                    HStack {
                        if currentTab != "+erder" {
                            Button {
                                if loadedData == true {
                                    showAlert.toggle()
                                } else {
                                    error = true

                                }
                            } label: {
                                Image(systemName: error ? "x.square" : "plus")
                                    .resizable()
                                    .foregroundStyle(error ? .red : .green)
                                    .frame(
                                        width: loadedData ? 25 : 0,
                                        height: loadedData ? 25 : 0,
                                        alignment: .center
                                    )
                                    .frame(width: loadedData ? 150 : 0)
                            }
                            .implicitAnimation(.snappy(duration: 1, extraBounce: 0.1))

                            // make assignment
                            .sheet(isPresented: $showAlert) {
                                VStack {
                                    Text("Create a new task!")
                                        .font(.largeTitle)
                                        .fontWeight(.black)

                                    TextField("Title", text: $name)
                                        .foregroundStyle(
                                            Color(
                                                hexadecimal: titleColor
                                                    == "#000000"
                                                    ? "#FFFFFF" : titleColor
                                            )
                                        )
                                        .textFieldStyle(
                                            OutlinedIconTextFieldStyle(
                                                icon: Image(
                                                    systemName: "scroll"
                                                ),
                                                iconColor: Color(
                                                    hexadecimal: titleColor
                                                )
                                            )
                                        )
                                        .padding()

                                    TextField(
                                        "Description (optional)",
                                        text: $description
                                    )
                                    .foregroundStyle(
                                        Color(
                                            hexadecimal: descriptionColor
                                                == "#000000"
                                                ? "#FFFFFF" : descriptionColor
                                        )
                                    )
                                    .textFieldStyle(
                                        OutlinedIconTextFieldStyle(
                                            icon: Image(
                                                systemName: "text.aligncenter"
                                            ),
                                            iconColor: Color(
                                                hexadecimal: descriptionColor
                                            )
                                        )
                                    )
                                    .padding()
                                    HStack {

                                        TextField(
                                            "Subject (optional)",
                                            text: $subject
                                        )
                                        .foregroundStyle(
                                            Color(
                                                hexadecimal: subjectColor
                                                    == "#000000"
                                                    ? "#FFFFFF" : subjectColor
                                            )
                                        )
                                        .textFieldStyle(
                                            OutlinedIconTextFieldStyle(
                                                icon: Image(
                                                    systemName: "graduationcap"
                                                ),
                                                iconColor: Color(
                                                    hexadecimal: subjectColor
                                                )
                                            )
                                        )
                                        .frame(
                                            width: screenWidth / 2.4,
                                            alignment: .leading
                                        )
                                        //.padding()

                                        if subjectPicker {
                                            Picker(
                                                "\(subject)",
                                                selection: $subject
                                            ) {
                                                // if subject == "" {
                                                Text(
                                                    "\(subject.replacingOccurrences(of: " ", with: "") != "" ? subject : "Enter Subject")"
                                                ).tag(subject)
                                                Section(
                                                    header: Text(
                                                        "Common Subjects"
                                                    )
                                                ) {
                                                    ForEach(
                                                        commonSub,
                                                        id: \.self
                                                    ) { i in
                                                        Text(i).tag(i)
                                                    }
                                                }
                                                //  }
                                                ForEach(
                                                    allSubjects.keys.sorted(),
                                                    id: \.self
                                                ) { tab in
                                                    if tab.lowercased()
                                                        .hasSuffix(" list")
                                                    {
                                                        Section(
                                                            header: Text(
                                                                "\(tab)"
                                                            )
                                                        ) {
                                                            if let
                                                                subjectsInTab =
                                                                allSubjects[tab]
                                                            {
                                                                ForEach(
                                                                    Array(
                                                                        Set(
                                                                            subjectsInTab
                                                                        )
                                                                    ),
                                                                    id: \.self
                                                                ) {
                                                                    chosenSubject
                                                                    in
                                                                    let count =
                                                                        subjectsInTab
                                                                        .filter
                                                                    {
                                                                        $0
                                                                            == chosenSubject
                                                                    }.count
                                                                    if count > 1
                                                                    {
                                                                        Text(
                                                                            "\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject") (\(count))"
                                                                        ).tag(
                                                                            chosenSubject
                                                                        )

                                                                    } else {
                                                                        Text(
                                                                            "\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject")"
                                                                        ).tag(
                                                                            chosenSubject
                                                                        )

                                                                    }
                                                                }

                                                            }
                                                        }
                                                    }
                                                }

                                            }
                                            .frame(width: screenWidth / 7.4)

                                            //.fixedSize()
                                        }
                                    }
                                    .padding()
                                    //.frame(maxWidth: screenWidth/2.5)

                                    Button {

                                        if name != "" {
                                            let task = DrawingBoardTask(
                                                title: name,
                                                subject: subject
                                                    .trimmingCharacters(
                                                        in: .whitespaces
                                                    ).isEmpty ? nil : subject,
                                                details: description
                                                    .trimmingCharacters(
                                                        in: .whitespaces
                                                    ).isEmpty
                                                    ? nil : description,
                                                createdDateText: Date.now
                                                    .formatted(),
                                                dueDate: dueDateForNewTask()
                                            )
                                            drawingBoardStore.appendTask(
                                                task,
                                                to: currentTab
                                            )
                                            names.append(task.title)
                                            subjects.append(task.subject ?? "")
                                            infoArray.append(task.details ?? "")
                                            dates.append(task.createdDateText)
                                            dueDates.append(task.dueDate)
                                            subjectExpandedStates.append(true)
                                            descriptionExpandedStates.append(
                                                true
                                            )


                                            selectDelete = Array(
                                                repeating: false,
                                                count: infoArray.count
                                            )

                                            for tab in bigDic.keys {
                                                allSubjects[tab] = []
                                                if tab.lowercased().hasSuffix(
                                                    " list"
                                                ) {
                                                    allSubjects[tab] = bigDic[
                                                        tab
                                                    ]?.subjects.filter {
                                                        !$0.trimmingCharacters(
                                                            in:
                                                                .whitespacesAndNewlines
                                                        ).isEmpty
                                                    } ?? []
                                                }
                                            }

                                            caughtUp = false
                                            assignmentAnimation = true
                                        } else {
                                            boxesFilled = true
                                        }
                                        subject = ""
                                        name = ""
                                        description = ""
                                        showAlert = false
                                    } label: {
                                        ZStack {

                                            Text("Create Assignment")
                                                .foregroundStyle(.green)
                                                //  .shadow(color: .gray, radius: 5, x: 0.0, y: 0.0)
                                                .background {
                                                    RoundedRectangle(
                                                        cornerRadius: 8,
                                                        style: .continuous
                                                    )
                                                    .stroke(.gray, lineWidth: 2)
                                                    .background(
                                                        .gray.opacity(0.1),
                                                        in: RoundedRectangle(
                                                            cornerRadius: 8,
                                                            style: .continuous
                                                        )
                                                    )
                                                    .frame(
                                                        width: screenWidth
                                                            / 7.5,
                                                        height: 45
                                                    )
                                                    .scaledToFit()
                                                }

                                        }
                                    }
                                    .padding()

                                }
                            }

                            Button {
                                showDeleteAllConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .resizable()
                                    .frame(
                                        width: loadedData ? 25 : 0,
                                        height: loadedData ? 25 : 0,
                                        alignment: .center
                                    )
                                    .foregroundStyle(.red)
                                    .frame(width: loadedData ? 150 : 0)
                            }
                            .alert(
                                "Delete All Assignments?",
                                isPresented: $showDeleteAllConfirmation
                            ) {
                                Button("Cancel", role: .cancel) {}
                                Button("Delete All", role: .destructive) {
                                    infoArray = []
                                    dates = []
                                    dueDates = []
                                    subjects = []
                                    names = []

                                    var list = bigDic[currentTab]
                                        ?? DrawingBoardList(name: currentTab)
                                    list.tasks = []
                                    bigDic[currentTab] = list
                                    caughtUp = false
                                }
                            } message: {
                                Text(
                                    "Are you sure you want to delete every assignment in this list?"
                                )
                            }

                        }
                    }
                    .alert(
                        "Enter A Title For This Assignment!",
                        isPresented: $boxesFilled
                    ) {
                        Button("Ok", role: .cancel) {}
                    }

                    .offset(x: screenWidth / 2 - 200)
                }

                VStack {

                    Picker("", selection: $currentTab) {
                        ForEach(Array(bigDic.keys), id: \.self) { i in
                            if i.lowercased().hasSuffix(" list") {
                                Text(i).tag(i)
                            }
                        }

                        Text("Edit Lists").tag("+erder")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .padding()

                    // both buttons

                    // Divider()
                    //   .frame(width: currentTab == "+erder" ? 0 : 300)
                    // .padding()

                    Text(
                        currentTab == "+erder"
                            ? "Edit Lists Below!"
                            : caughtUp ? "Add Objectives Here!" : ""
                    )
                    .font(.title)
                    .padding(caughtUp ? 30 : 0)

                    if loadedData && currentTab != "+erder"
                        && bigDic[currentTab]?.tasks.isEmpty != true
                        && caughtUp == false
                        && selectDelete.count == infoArray.count
                    {

                        ScrollView {

                            ForEach(infoArray.indices, id: \.self) { index in

                                Spacer()
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .foregroundColor(.black)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(.white, lineWidth: 2)
                                            //  .frame(width: screenWidth/2.1)

                                        )
                                        .shadow(radius: 5)
                                    //  .frame(width: screenWidth/2.1)

                                    VStack {
                                        HStack {

                                            Image(
                                                systemName: selectDelete[index]
                                                    ? "checkmark.circle.fill"
                                                    : "checkmark"
                                            )
                                            .resizable()
                                            .frame(
                                                width: 100,
                                                height: 100,
                                                alignment: .center
                                            )
                                            .scaleEffect(
                                                selectDelete[index] ? 1.0 : 0.5
                                            )
                                            .foregroundStyle(
                                                selectDelete[index]
                                                    ? .red : .blue
                                            )

                                            .implicitAnimation(.snappy())
                                            // only works on mac
                                            .onHover { hovering in
                                                if hovering {
                                                    selectDelete[index] = true
                                                } else {
                                                    selectDelete = Array(
                                                        repeating: false,
                                                        count: infoArray.count
                                                    )

                                                }
                                            }
                                            //  .offset(x: 50)
                                            .onChange(of: names[index]) {
                                                selectDelete[index] = false
                                            }
                                            .onChange(of: subjects[index]) {
                                                selectDelete[index] = false
                                            }
                                            .onChange(of: infoArray[index]) {
                                                selectDelete[index] = false
                                            }
                                            .onChange(of: dueDates[index]) {
                                                selectDelete[index] = false
                                            }
                                            .onTapGesture {
                                                selectDelete[index].toggle()

                                                if selectDelete[index] == false
                                                {
                                                    selectDelete.remove(
                                                        at: index
                                                    )
                                                    infoArray.remove(at: index)
                                                    names.remove(at: index)
                                                    subjects.remove(at: index)
                                                    dates.remove(at: index)
                                                    dueDates.remove(at: index)
                                                    subjectExpandedStates.remove(
                                                        at: index
                                                    )
                                                    descriptionExpandedStates
                                                        .remove(at: index)

                                                    drawingBoardStore
                                                        .removeTask(
                                                            at: index,
                                                            from: currentTab
                                                        )


                                                    completed += 1
                                                    if infoArray.isEmpty {
                                                        selectDelete = []
                                                        caughtUp = true
                                                    }
                                                }
                                            }

                                            Spacer(minLength: 0)

                                            VStack {

                                                HStack {

                                                    // title
                                                    ZStack {
                                                        TextField(
                                                            "\(names[index])"
                                                                .trimmingCharacters(
                                                                    in:
                                                                        .whitespacesAndNewlines
                                                                ),
                                                            text: $names[index]
                                                        )
                                                        .textFieldStyle(
                                                            UnderlinedTextFieldStyle(
                                                                color: Color(
                                                                    hexadecimal:
                                                                        titleColor
                                                                )
                                                            )
                                                        )
                                                        .foregroundStyle(
                                                            Color(
                                                                hexadecimal:
                                                                    titleColor
                                                            )
                                                        )
                                                        //   .capitalized()
                                                        .onChange(
                                                            of: names[index]
                                                        ) {
                                                            saveCurrentTasks()
                                                        }
                                                        .onSubmit {
                                                            saveCurrentTasks()
                                                        }
                                                        .fontWeight(.heavy)
                                                        .font(.largeTitle)
                                                        //  .offset(x: subjects[index] != " " ? 100 : (infoArray[index] != " " ? 100 : 0) )
                                                        .padding()
                                                        //    .fixedSize(horizontal: infoArray[index] != " " ? false : true, vertical: false)
                                                        .multilineTextAlignment(
                                                            descriptionExpandedStates[
                                                                index
                                                            ]
                                                                ? .leading
                                                                : subjectExpandedStates[
                                                                    index
                                                                ]
                                                                    ? .leading
                                                                    : .center
                                                        )
                                                        // .fixedSize(horizontal: true, vertical: false)

                                                    }
                                                    .frame(
                                                        maxWidth:
                                                            descriptionExpandedStates[
                                                            index
                                                        ]
                                                            ? screenWidth / 3
                                                            : subjectExpandedStates[
                                                                index
                                                            ]
                                                                ? screenWidth
                                                                    / 2
                                                                : screenWidth,
                                                        alignment:
                                                            descriptionExpandedStates[
                                                            index
                                                        ]
                                                            ? .leading
                                                            : subjectExpandedStates[
                                                                index
                                                            ]
                                                                ? .leading
                                                                : .center
                                                    )
                                                    .fixedSize(
                                                        horizontal: true,
                                                        vertical: false
                                                    )
                                                    Spacer()
                                                    // description texteditor
                                                    if descriptionExpandedStates[
                                                        index
                                                    ] {

                                                        HStack {

                                                            // button to get rid of every space
                                                            if emptyClear {
                                                                Button {
                                                                    infoArray[
                                                                        index
                                                                    ] =
                                                                        infoArray[
                                                                            index
                                                                        ]
                                                                        .trimmingCharacters(
                                                                            in:
                                                                                .whitespacesAndNewlines
                                                                        )

                                                                    if infoArray[
                                                                        index
                                                                    ]
                                                                        == "Enter new value"
                                                                    {
                                                                        infoArray[
                                                                            index
                                                                        ] = ""
                                                                    }

                                                                } label: {
                                                                    ZStack {
                                                                        RoundedRectangle(
                                                                            cornerRadius:
                                                                                8,
                                                                            style:
                                                                                .continuous
                                                                        )
                                                                        .stroke(
                                                                            .white,
                                                                            lineWidth:
                                                                                2
                                                                        )
                                                                        .frame(
                                                                            width:
                                                                                30,
                                                                            height:
                                                                                38
                                                                        )
                                                                        .background(
                                                                            Color(
                                                                                hexadecimal:
                                                                                    descriptionColor
                                                                            )
                                                                            .opacity(
                                                                                0.1
                                                                            ),
                                                                            in:
                                                                                RoundedRectangle(
                                                                                    cornerRadius:
                                                                                        8,
                                                                                    style:
                                                                                        .continuous
                                                                                )
                                                                        )

                                                                        Image(
                                                                            systemName:
                                                                                "note.text"
                                                                        )
                                                                        .foregroundStyle(
                                                                            Color(
                                                                                hexadecimal:
                                                                                    descriptionColor
                                                                            )
                                                                        )
                                                                        .shadow(
                                                                            color:
                                                                                .gray,
                                                                            radius:
                                                                                5,
                                                                            x:
                                                                                0,
                                                                            y: 0
                                                                        )
                                                                    }
                                                                }
                                                            }

                                                            TextEditor(
                                                                text:
                                                                    $infoArray[
                                                                        index
                                                                    ]
                                                            )
                                                            .overlay(
                                                                alignment:
                                                                    .topLeading
                                                            ) {
                                                                RoundedRectangle(
                                                                    cornerRadius:
                                                                        8,
                                                                    style:
                                                                        .continuous
                                                                )
                                                                .stroke(
                                                                    Color(
                                                                        hexadecimal:
                                                                            descriptionColor
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                                .allowsHitTesting(
                                                                    false
                                                                )

                                                                if infoArray[
                                                                    index
                                                                ].isEmpty {
                                                                    Text(
                                                                        "Add a description here!"
                                                                    )
                                                                    .foregroundStyle(
                                                                        .gray
                                                                    )
                                                                    .padding(
                                                                        .top,
                                                                        8
                                                                    )
                                                                    .padding(
                                                                        .leading,
                                                                        5
                                                                    )
                                                                    .allowsHitTesting(
                                                                        false
                                                                    )
                                                                }
                                                            }
                                                            //  .multilineTextAlignment(.center)

                                                            .foregroundStyle(
                                                                Color(
                                                                    hexadecimal:
                                                                        descriptionColor
                                                                )
                                                            )

                                                            .onChange(
                                                                of: infoArray[
                                                                    index
                                                                ]
                                                            ) {
                                                                saveCurrentTasks()
                                                            }
                                                            .onSubmit {
                                                                saveCurrentTasks()
                                                            }

                                                            .font(.title3)
                                                            .padding()

                                                        }
                                                        //  .offset(x:-15)
                                                        .padding()
                                                        //  .frame(maxWidth: infoArray[index] != " " ? screenWidth/2 : 0)
                                                        .frame(
                                                            maxWidth: screenWidth
                                                                / 3,
                                                            maxHeight:
                                                                screenHeight / 5
                                                        )
                                                        .fixedSize(
                                                            horizontal: false,
                                                            vertical: true
                                                        )

                                                    }

                                                    // subject picker and textfield
                                                    if subjectExpandedStates[
                                                        index
                                                    ] {
                                                        Spacer(minLength: 0)
                                                        HStack {
                                                            if subjectPicker {
                                                                Button {
                                                                    pickerOpen
                                                                        .toggle()
                                                                } label: {
                                                                    ZStack {
                                                                        RoundedRectangle(
                                                                            cornerRadius:
                                                                                8,
                                                                            style:
                                                                                .continuous
                                                                        )
                                                                        .stroke(
                                                                            Color(
                                                                                hexadecimal:
                                                                                    subjectColor
                                                                            ),
                                                                            lineWidth:
                                                                                2
                                                                        )
                                                                        .frame(
                                                                            width:
                                                                                30,
                                                                            height:
                                                                                38
                                                                        )
                                                                        .background(
                                                                            Color(
                                                                                hexadecimal:
                                                                                    subjectColor
                                                                            )
                                                                            .opacity(
                                                                                0.1
                                                                            ),
                                                                            in:
                                                                                RoundedRectangle(
                                                                                    cornerRadius:
                                                                                        8,
                                                                                    style:
                                                                                        .continuous
                                                                                )
                                                                        )

                                                                        Image(
                                                                            systemName:
                                                                                "book.closed"
                                                                        )
                                                                        .foregroundStyle(
                                                                            Color(
                                                                                hexadecimal:
                                                                                    subjectColor
                                                                            )
                                                                        )
                                                                        .shadow(
                                                                            color:
                                                                                .gray,
                                                                            radius:
                                                                                5,
                                                                            x:
                                                                                0,
                                                                            y: 0
                                                                        )

                                                                    }
                                                                }
                                                                Picker(
                                                                    "\(subjects[index])",
                                                                    selection:
                                                                        $subjects[
                                                                            index
                                                                        ]
                                                                ) {
                                                                    Section(
                                                                        header:
                                                                            Text(
                                                                                "Common Subjects"
                                                                            )
                                                                    ) {
                                                                        ForEach(
                                                                            commonSub,
                                                                            id:
                                                                                \.self
                                                                        ) { i in
                                                                            Text(
                                                                                i
                                                                            )
                                                                            .tag(
                                                                                i
                                                                            )
                                                                        }
                                                                    }
                                                                    ForEach(
                                                                        allSubjects
                                                                            .keys
                                                                            .sorted(),
                                                                        id:
                                                                            \.self
                                                                    ) { tab in
                                                                        if tab
                                                                            .lowercased()
                                                                            .hasSuffix(
                                                                                " list"
                                                                            )
                                                                        {
                                                                            Section(
                                                                                header:
                                                                                    Text(
                                                                                        "\(tab)"
                                                                                    )
                                                                            ) {
                                                                                if let
                                                                                    subjectsInTab =
                                                                                    allSubjects[
                                                                                        tab
                                                                                    ]
                                                                                {
                                                                                    ForEach(
                                                                                        Array(
                                                                                            Set(
                                                                                                subjectsInTab
                                                                                            )
                                                                                        ),
                                                                                        id:
                                                                                            \.self
                                                                                    )
                                                                                    {
                                                                                        chosenSubject
                                                                                        in
                                                                                        let count =
                                                                                            subjectsInTab
                                                                                            .filter
                                                                                        {
                                                                                            $0
                                                                                                == chosenSubject
                                                                                        }
                                                                                            .count
                                                                                        if count
                                                                                            > 1
                                                                                        {

                                                                                            Text(
                                                                                                "\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject") (\(count))"
                                                                                            )
                                                                                            .tag(
                                                                                                chosenSubject
                                                                                            )

                                                                                        } else
                                                                                        {

                                                                                            Text(
                                                                                                "\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject")"
                                                                                            )
                                                                                            .tag(
                                                                                                chosenSubject
                                                                                            )

                                                                                        }

                                                                                    }
                                                                                }
                                                                            }

                                                                        }
                                                                    }
                                                                }

                                                                .scaleEffect(
                                                                    pickerOpen
                                                                        ? 1.0
                                                                        : 0.0
                                                                )
                                                                .frame(
                                                                    maxWidth:
                                                                        pickerOpen
                                                                        ? screenWidth
                                                                            / 4
                                                                        : 0
                                                                )
                                                                .fixedSize(
                                                                    horizontal:
                                                                        true,
                                                                    vertical:
                                                                        false
                                                                )
                                                                .onChange(
                                                                    of:
                                                                        subjects[
                                                                            index
                                                                        ]
                                                                ) {
                                                                    saveCurrentTasks()
                                                                }
                                                            }
                                                            TextField(
                                                                "\(subjects[index])"
                                                                    .trimmingCharacters(
                                                                        in:
                                                                            .whitespacesAndNewlines
                                                                    ),
                                                                text: $subjects[
                                                                    index
                                                                ]
                                                            )
                                                            .textFieldStyle(
                                                                subjectPicker
                                                                    ? RoundedTextFieldStyle(
                                                                        iconColor:
                                                                            Color(
                                                                                hexadecimal:
                                                                                    subjectColor
                                                                            )
                                                                    )
                                                                    : RoundedTextFieldStyle(
                                                                        icon:
                                                                            Image(
                                                                                systemName:
                                                                                    "book.closed"
                                                                            ),
                                                                        iconColor:
                                                                            Color(
                                                                                hexadecimal:
                                                                                    subjectColor
                                                                            )
                                                                    )
                                                            )
                                                            // .textFieldStyle(RoundedTextFieldStyle(iconColor: Color(hexadecimal: subjectColor)))
                                                            .onChange(
                                                                of: subjects[
                                                                    index
                                                                ]
                                                            ) {
                                                                saveCurrentTasks()
                                                            }

                                                            .onSubmit {
                                                                saveCurrentTasks()
                                                            }
                                                            .font(.title2)

                                                        }
                                                        .tint(
                                                            Color(
                                                                hexadecimal:
                                                                    subjectColor
                                                            )
                                                        )
                                                        .foregroundStyle(
                                                            Color(
                                                                hexadecimal:
                                                                    subjectColor
                                                            )
                                                        )
                                                        .padding()
                                                        .frame(
                                                            maxWidth:
                                                                descriptionExpandedStates[
                                                                    index
                                                                ]
                                                                ? screenWidth
                                                                    / 3
                                                                : screenWidth
                                                                    / 2
                                                        )
                                                        .fixedSize(
                                                            horizontal: true,
                                                            vertical: false
                                                        )
                                                    }

                                                    VStack(spacing: 10) {
                                                        DrawingBoardFieldToggleButton(
                                                            systemName:
                                                                "book.closed",
                                                            color: Color(
                                                                hexadecimal:
                                                                    subjectColor
                                                            ),
                                                            isExpanded:
                                                                subjectExpandedStates[
                                                                    index
                                                                ],
                                                            accessibilityLabel:
                                                                "Toggle subject"
                                                        ) {
                                                            subjectExpandedStates[
                                                                index
                                                            ].toggle()
                                                            saveCurrentTasks()
                                                        }

                                                        DrawingBoardFieldToggleButton(
                                                            systemName:
                                                                "note.text",
                                                            color: Color(
                                                                hexadecimal:
                                                                    descriptionColor
                                                            ),
                                                            isExpanded:
                                                                descriptionExpandedStates[
                                                                    index
                                                                ],
                                                            accessibilityLabel:
                                                                "Toggle description"
                                                        ) {
                                                            descriptionExpandedStates[
                                                                index
                                                            ].toggle()
                                                            saveCurrentTasks()
                                                        }
                                                    }
                                                    //      .offset(y: -25)
                                                }
                                                //.offset(x: 100)

                                                Divider()
                                                    //   .offset(x: 50)
                                                    .frame(
                                                        maxWidth: screenWidth
                                                            / 1.2,
                                                        alignment: .leading
                                                    )

                                                // dates
                                                HStack {

                                                    DatePicker(
                                                        selection: $dueDates[
                                                            index
                                                        ],
                                                        displayedComponents: [
                                                            .hourAndMinute,
                                                            .date,
                                                        ],
                                                        label: {
                                                            Text("Due: ")
                                                        }
                                                    )
                                                    .onChange(of: dueDates) {
                                                        saveCurrentTasks()
                                                    }
                                                    .datePickerStyle(.compact)
                                                    .padding()
                                                    .fixedSize()

                                                    Spacer()
                                                    Text(
                                                        "Created: \(dates[index])"
                                                    )
                                                }
                                            }

                                        }
                                    }
                                    .padding(20)
                                }
                                .padding(7.5)
                                .onAppear {
                                    if hasAppeared == false {

                                        if infoArray[index] == "Enter new value"
                                        {
                                            infoArray[index] = ""
                                        }
                                        if subjects[index] == "Enter new value"
                                        {
                                            subjects[index] = ""
                                        }
                                        saveCurrentTasks()

                                        hasAppeared = true
                                    }

                                }
                                .strikethrough(selectDelete[index])
                                .implicitAnimation(.bouncy(duration: 1))

                            }
                            .foregroundStyle(.blue)
                            .padding(10)

                        }
                        //     .implicitAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 1.0))
                        .implicitAnimation(.bouncy(duration: 1))
                        .offset(y: -25)
                        .defaultScrollAnchor(
                            infoArray.count > 2 ? .bottom : .top
                        )

                        // the editing tab
                    } else if currentTab == "+erder" {
                        HStack {
                            VStack {
                                Image(systemName: "minus")
                                    .frame(width: 50, height: 25)
                                    .background(
                                        .brown,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )

                                Divider()

                                Picker("Delete", selection: $deleteTabs) {
                                    ForEach(Array(bigDic.keys), id: \.self) {
                                        i in
                                        if i.lowercased().hasSuffix(" list") {
                                            Text(i).tag(i)
                                        }
                                    }
                                }
                                .pickerStyle(.automatic)

                                Button {
                                    if deleteTabs != "Basic List" {
                                        bigDic.removeValue(forKey: deleteTabs)

                                    } else {
                                        deleteWarning = true
                                    }

                                } label: {
                                    Text("Delete List")
                                }

                            }
                            .alert(
                                "CAN NOT DELETE STARTER LIST",
                                isPresented: $deleteWarning
                            ) {
                                Button("Ok") {}
                            }

                            Divider()

                            VStack {
                                Image(systemName: "plus")
                                    .frame(width: 50, height: 25)
                                    .background(
                                        .brown,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )

                                Divider()

                                TextField("New List Name", text: $createTab)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    if bigDic.keys.contains(createTab)
                                        || bigDic.keys.contains(
                                            "\(createTab) List"
                                        )
                                    {
                                        addWarning = true

                                    } else {

                                        if createTab.lowercased().hasSuffix(
                                            " list"
                                        ) {
                                            bigDic["\(createTab)"] =
                                                DrawingBoardList(
                                                    name: createTab
                                                )

                                        } else {
                                            if createTab != "" {
                                                bigDic["\(createTab) List"] =
                                                    DrawingBoardList(
                                                        name: "\(createTab) List"
                                                    )
                                            }
                                        }
                                    }
                                    createTab = ""
                                } label: {
                                    Text("Submit Name")
                                }
                            }
                            .alert(
                                "Already An Existing Name!",
                                isPresented: $addWarning
                            ) {
                                Button("Ok") {}
                            }

                        }
                        .fixedSize()

                    }
                }
                Spacer()
            }

        }
        .onAppear {
            loadCurrentList()
        }
        .onChange(of: selectedTab) {
            loadCurrentList()
        }
        .onChange(of: currentTab) {
            if currentTab != "+erder" {
                loadCurrentList()
            }
        }

    }
}

struct OutlinedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white, lineWidth: 5)
            }
    }
}
struct RoundedTextFieldStyle: TextFieldStyle {

    @State var icon: Image?
    @State var iconColor: Color?

    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack {
            if icon != nil && iconColor != nil {
                icon
                    .foregroundColor(iconColor)
            }
            configuration
        }
        .padding(.vertical)
        .padding(.horizontal, 24)
        .background(.gray.opacity(0.1), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color(iconColor ?? .white), lineWidth: 5)
        )
        .clipShape(Capsule())

    }
}

struct UnderlinedTextFieldStyle: TextFieldStyle {
    @State var color: Color?
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 8)
            .background(
                VStack {
                    Spacer()
                    Color(color ?? .white)
                        .frame(height: 2)
                }
            )
    }
}

struct OutlinedIconTextFieldStyle: TextFieldStyle {

    @State var icon: Image?
    @State var iconColor: Color?

    func _body(configuration: TextField<Self._Label>) -> some View {
        HStack {
            if icon != nil && iconColor != nil {
                icon
                    .foregroundColor(iconColor)
            }
            configuration
        }
        .padding()
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(iconColor ?? .white, lineWidth: 5)
        }
    }
}

func calculateSecondsUntil(timeString: String) -> Int {
    // must do this because dateformatter is a class
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"

    let now = Date()
    let calendar = Calendar.current

    // get today's date components
    let components = calendar.dateComponents([.year, .month, .day], from: now)

    guard let year = components.year,
        let month = components.month,
        let day = components.day
    else {
        print("Error: Unable to get current date components.")
        return 0
    }

    // combine today's date with the given time
    let fullDateString = "\(year)-\(month)-\(day) \(timeString)"
    let dateTimeStringFormatter = DateFormatter()
    dateTimeStringFormatter.dateFormat = "yyyy-MM-dd HH:mm"

    // makes sure that it does not return a nil
    guard let targetDate = dateTimeStringFormatter.date(from: fullDateString)
    else {
        print("Error: Unable to parse time string '\(fullDateString)'.")
        return 0
    }

    let secondsUntilTargetDate = Int(targetDate.timeIntervalSince(now))

    return secondsUntilTargetDate
}

func noSpace(string: String) -> String {
    return string.trimmingCharacters(in: .whitespaces)

}
