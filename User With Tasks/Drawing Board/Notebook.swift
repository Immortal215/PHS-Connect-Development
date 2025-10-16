import SwiftUI 
import Pow

struct Notebook: View {
    @State var screenWidth = UIScreen.main.bounds.width
    @State var screenHeight = UIScreen.main.bounds.height
    
    @AppStorage("completed") var completed = 0
    
    @AppStorage("selectedTab") var selectedTab = 1
    @AppStorage("currentTab") var currentTab = "Basic List"
    
    @State var retrieveBigDic: [String: [String: [String]]] = UserDefaults.standard.dictionary(forKey: "DicKey") as? [String: [String: [String]]] ?? ["Basic List": ["subjects": [String()], "names": [String()], "description": [String()], "date": [String()]]]
    @State var bigDic: [String: [String: [String]]] = ["Basic List": ["subjects": [String()], "names": [String()], "description": [String()], "date": [String()]]]
    
    @State var retrieveDueDic: [String: [Date]] = UserDefaults.standard.dictionary(forKey: "DueDicKey") as? [String: [Date]] ?? ["Basic List": [Date()]]
    @State var dueDic: [String: [Date]] = ["Basic List": []]
    
    @State var allSubjects: [String: [String]] = [:]
    
    @State var subjects: [String] = []
    
    @State var names: [String] = []
    
    @State var infoArray: [String] = []
    
    @State var dates: [String] = []
    
    @State var retrieveDueArray: [Date] = UserDefaults.standard.array(forKey: "due") as? [Date] ?? []
    @State var dueDates: [Date] = []
    @State var commonSub = ["English", "Math", "Science", "History"]
    @State var createTab = ""
    @State var deleteTabs = ""
    @State var deleteWarning = false
    @State var addWarning = false
    
    @AppStorage("duedatesetter") var dueDateSetter = "Two Days"
    @AppStorage("dueDater") var dueDater = "07:00"
    @AppStorage("organizedAssignments") var organizedAssignments = "Due By Descending (Recent to Oldest)"
    
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
    @State var deleted = false
    @State var error = false
    @State var boxesFilled = false
    @State var settings = false
    @State var selectDelete: [Bool] = []
    @State var assignmentAnimation = false
    @State var pickerOpen = false
    @State var hasAppeared = false
    
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
                                    .frame(width: loadedData ? 25 : 0, height: loadedData ? 25 : 0, alignment: .center)
                                    .frame(width: loadedData ? 150 : 0)
                            }
                            .animation(.snappy(duration: 1, extraBounce: 0.1))
                            
                            // make assignment
                            .sheet( isPresented: $showAlert) {
                                VStack {
                                    Text("Create a new task!")
                                        .font(.largeTitle)
                                        .fontWeight(.black)
                                    
                                    TextField("Title", text: $name)
                                        .foregroundStyle(Color(hexadecimal: titleColor == "#000000" ? "#FFFFFF" : titleColor))
                                        .textFieldStyle(OutlinedIconTextFieldStyle(icon: Image(systemName: "scroll"), iconColor: Color(hexadecimal: titleColor)))
                                        .padding()
                                    
                                    TextField("Description (optional)", text: $description)
                                        .foregroundStyle(Color(hexadecimal: descriptionColor == "#000000" ? "#FFFFFF" : descriptionColor))
                                        .textFieldStyle(OutlinedIconTextFieldStyle(icon: Image(systemName: "text.aligncenter"), iconColor: Color(hexadecimal: descriptionColor)))
                                        .padding()
                                    HStack {
                                        
                                        TextField("Subject (optional)", text: $subject)
                                            .foregroundStyle(Color(hexadecimal: subjectColor == "#000000" ? "#FFFFFF" : subjectColor))
                                            .textFieldStyle(OutlinedIconTextFieldStyle(icon: Image(systemName: "graduationcap"), iconColor: Color(hexadecimal: subjectColor)))
                                            .frame(width: screenWidth/2.4, alignment: .leading)
                                        //.padding()
                                        
                                        if subjectPicker {
                                            Picker("\(subject)", selection: $subject) {
                                                // if subject == "" {
                                                Text("\(subject.replacingOccurrences(of: " ", with: "") != "" ? subject : "Enter Subject")").tag(subject)
                                                Section(header : Text("Common Subjects")) {
                                                    ForEach(commonSub, id: \.self) { i in
                                                        Text(i).tag(i)
                                                    }
                                                }
                                                //  }
                                                ForEach(allSubjects.keys.sorted(), id: \.self) { tab in
                                                    if tab.lowercased().hasSuffix(" list") {
                                                        Section(header: Text("\(tab)")) {
                                                            if let subjectsInTab = allSubjects[tab] {
                                                                ForEach(Array(Set(subjectsInTab)), id: \.self) { chosenSubject in
                                                                    let count = subjectsInTab.filter { $0 == chosenSubject }.count
                                                                    if count > 1 {
                                                                        Text("\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject") (\(count))").tag(chosenSubject)
                                                                        
                                                                    } else {
                                                                        Text("\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject")").tag(chosenSubject)
                                                                        
                                                                    }
                                                                }
                                                                
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                            }
                                            .frame(width: screenWidth/7.4)
                                            
                                            //.fixedSize()
                                        }
                                    }
                                    .padding()
                                    //.frame(maxWidth: screenWidth/2.5)
                                    
                                    Button {
                                        
                                        if name != "" {
                                            var tabDict = bigDic[currentTab]
                                            var namesArray = tabDict!["names"]!
                                            var subjectsArray = tabDict!["subjects"]!
                                            var infosArray = tabDict!["description"]!
                                            var datesArray = tabDict!["date"]!
                                            
                                            
                                            if namesArray == [] || namesArray == [""] {
                                                
                                                namesArray = []
                                                
                                                subjectsArray = []
                                                
                                                infosArray = []
                                                
                                                datesArray = []
                                                
                                            }
                                            
                                            namesArray.append(name)
                                            tabDict!["names"] = namesArray
                                            bigDic[currentTab] = tabDict
                                            names = namesArray
                                            
                                            subjectsArray.append(subject.trimmingCharacters(in: .whitespaces) == "" ? " " : subject)
                                            tabDict!["subjects"] = subjectsArray
                                            bigDic[currentTab] = tabDict
                                            subjects = subjectsArray
                                            
                                            infosArray.append(description.trimmingCharacters(in: .whitespaces) == "" ? " " : description)
                                            tabDict!["description"] = infosArray
                                            bigDic[currentTab] = tabDict
                                            infoArray = infosArray
                                            
                                            datesArray.append(Date.now.formatted())
                                            tabDict!["date"] = datesArray
                                            bigDic[currentTab] = tabDict
                                            dates = datesArray
                                            
                                            UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                            
                                            // im too lazy to make the algorithm for this 
                                            if dueDateSetter == "One Day" {
                                                dueDates.append(Date(timeIntervalSinceNow: 86401 + TimeInterval(calculateSecondsUntil(timeString: dueDater))))
                                            } else if dueDateSetter == "One Hour" {
                                                dueDates.append(Date(timeIntervalSinceNow: 3600))
                                            } else if dueDateSetter == "6 Hours" {
                                                dueDates.append(Date(timeIntervalSinceNow: 21600))
                                            } else if dueDateSetter == "Two Days" {
                                                dueDates.append(Date(timeIntervalSinceNow: 172801) + TimeInterval(calculateSecondsUntil(timeString: dueDater)))
                                            } else if dueDateSetter == "Five Days" {
                                                dueDates.append(Date(timeIntervalSinceNow: 432001 + TimeInterval(calculateSecondsUntil(timeString: dueDater))))
                                            } else if dueDateSetter == "Today" {
                                                dueDates.append(Date(timeIntervalSinceNow: TimeInterval(calculateSecondsUntil(timeString: dueDater))))
                                            } else if dueDateSetter == "Four Days" {
                                                dueDates.append(Date(timeIntervalSinceNow: 345601 + TimeInterval(calculateSecondsUntil(timeString: dueDater))))
                                            }
                                            
                                            dueDic[currentTab] = dueDates
                                            
                                            UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                            
                                            selectDelete = Array(repeating: false, count: infoArray.count)
                                            
                                            for tab in bigDic.keys {
                                                allSubjects[tab] = []
                                                if tab.lowercased().hasSuffix(" list") {
                                                    if let subjects = bigDic[tab]?["subjects"] as? [String] {
                                                        allSubjects[tab] = subjects
                                                    }
                                                }
                                            }
                                            
                                            caughtUp = false
                                            deleted = false
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
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(.gray, lineWidth: 2)
                                                        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        .frame(width: screenWidth/7.5, height: 45)
                                                        .scaledToFit()
                                                }
                                            
                                        }
                                    }
                                    .padding()
                                    
                                } 
                            }
                            
                            Button {
                                deleted.toggle()
                                
                                if deleted == false  {
                                    infoArray = []
                                    dates = []
                                    dueDates = []
                                    subjects = []
                                    names = []
                                    
                                    bigDic[currentTab] = [
                                        "subjects": [],
                                        "names": [],
                                        "description": [],
                                        "date": []
                                    ]
                                    
                                    dueDic[currentTab] = []
                                    
                                    UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                    deleted = false
                                    caughtUp = false
                                }  
                                
                            } label: {
                                Image(systemName: deleted ? "trash.fill" : "trash")
                                    .resizable()
                                    .frame(width: loadedData ? 25 : 0, height: loadedData ? 25 : 0, alignment: .center)
                                    .foregroundStyle(.red)
                                    .frame(width: loadedData ? 150 : 0)
                                    .scaleEffect(deleted ? 1.4 : 1.0)
                            }
                            .animation(.bouncy(duration: 1, extraBounce: 0.1))
                            
                        }
                    }
                    .alert("Enter A Title For This Assignment!", isPresented: $boxesFilled) {
                        Button("Ok", role: .cancel) {}
                    }
                    
                    .offset(x: screenWidth/2 - 200)
                }
                
                VStack {
                    
                    Picker("",selection: $currentTab) {
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
                    
                    Text(currentTab == "+erder" ? "Edit Lists Below!" : caughtUp ? "Add Objectives Here!" : "")
                        .font(.title)
                        .padding(caughtUp ? 30 : 0)
                    
                    
                    if loadedData && currentTab != "+erder" && bigDic[currentTab]?["description"]?.isEmpty != true && caughtUp == false && selectDelete.count == infoArray.count {
                        
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
                                            
                                            
                                            
                                            Image(systemName: selectDelete[index] ? "checkmark.circle.fill" : "checkmark")
                                                .resizable()
                                                .frame(width: 100, height: 100, alignment: .center)
                                                .scaleEffect(selectDelete[index] ? 1.0 : 0.5)
                                                .foregroundStyle(selectDelete[index] ? .red : .blue)
                                            
                                                .animation(.snappy())
                                            // only works on mac
                                                .onHover { hovering in
                                                    if hovering {
                                                        selectDelete[index] = true
                                                    } else {
                                                        selectDelete = Array(repeating: false, count: infoArray.count)
                                                        
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
                                                    
                                                    if selectDelete[index] == false {
                                                        selectDelete.remove(at: index)
                                                        infoArray.remove(at: index)
                                                        names.remove(at: index)
                                                        subjects.remove(at: index)
                                                        dates.remove(at: index)
                                                        dueDates.remove(at: index)
                                                        
                                                        bigDic[currentTab]!["names"]! = names
                                                        bigDic[currentTab]!["subjects"]! = subjects
                                                        bigDic[currentTab]!["description"]! = infoArray
                                                        bigDic[currentTab]!["date"]! = dates
                                                        dueDic[currentTab]! = dueDates
                                                        
                                                        UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                        UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                                        
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
                                                        TextField("\(names[index])".trimmingCharacters(in: .whitespacesAndNewlines), text: $names[index])
                                                            .textFieldStyle(UnderlinedTextFieldStyle(color: Color(hexadecimal: titleColor)))
                                                            .foregroundStyle(Color(hexadecimal: titleColor))
                                                        //   .capitalized()
                                                            .onChange(of: names[index]) {
                                                                bigDic[currentTab]!["subjects"] = subjects
                                                                bigDic[currentTab]!["description"] = infoArray
                                                                
                                                                bigDic[currentTab]!["names"] = names
                                                                
                                                                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                if infoArray[index] == " " {
                                                                    infoArray[index] = "Enter new value"
                                                                    Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { timer in
                                                                        if infoArray[index] == "Enter new value" {
                                                                            infoArray[index] = " "
                                                                            bigDic[currentTab]!["description"] = infoArray
                                                                            UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                            
                                                                        }
                                                                    }
                                                                }
                                                                if subjects[index] == " " {
                                                                    subjects[index] = "Enter new value"
                                                                    Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { timer in
                                                                        if subjects[index] == "Enter new value" {
                                                                            subjects[index] = " "
                                                                            bigDic[currentTab]!["subjects"] = subjects
                                                                            UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                        }
                                                                    }
                                                                }
                                                                
                                                                bigDic[currentTab]!["subjects"] = subjects
                                                                bigDic[currentTab]!["description"] = infoArray
                                                                
                                                                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                            }
                                                            .onSubmit {
                                                                if infoArray[index] == "Enter new value" {
                                                                    infoArray[index] = " "
                                                                }
                                                                if subjects[index] == "Enter new value" {
                                                                    subjects[index] = " "
                                                                }
                                                                bigDic[currentTab]!["subjects"] = subjects
                                                                bigDic[currentTab]!["description"] = infoArray
                                                                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                            }
                                                            .fontWeight(.heavy)
                                                            .font(.largeTitle)
                                                        //  .offset(x: subjects[index] != " " ? 100 : (infoArray[index] != " " ? 100 : 0) )
                                                            .padding()
                                                        //    .fixedSize(horizontal: infoArray[index] != " " ? false : true, vertical: false)
                                                            .multilineTextAlignment(infoArray[index] != " " ? .leading : subjects[index] != " " ? .leading : .center)
                                                        // .fixedSize(horizontal: true, vertical: false)
                                                        
                                                    }
                                                    .frame(maxWidth: infoArray[index] != " " ? screenWidth/3 : subjects[index] != " " ? screenWidth/2 : screenWidth, alignment: infoArray[index] != " " ? .leading : subjects[index] != " " ? .leading : .center)
                                                    .fixedSize(horizontal: true, vertical: false)
                                                    Spacer() 
                                                    // description texteditor
                                                    if infoArray[index] != " " {
                                                        
                                                        
                                                        HStack {
                                                            
                                                            // button to get rid of every space
                                                            if emptyClear {              
                                                                Button {
                                                                    infoArray[index] = infoArray[index].trimmingCharacters(in: .whitespacesAndNewlines)
                                                                    
                                                                    if infoArray[index] == "Enter new value" {
                                                                        infoArray[index] = " "
                                                                    }
                                                                    
                                                                    
                                                                } label: {
                                                                    ZStack {
                                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                            .stroke(.white, lineWidth: 2)
                                                                            .frame(width: 30, height: 38)
                                                                            .background(Color(hexadecimal: descriptionColor).opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                                        
                                                                        
                                                                        Image(systemName: "note.text")
                                                                            .foregroundStyle(Color(hexadecimal: descriptionColor))
                                                                            .shadow(color: .gray, radius: 5, x: 0, y: 0)
                                                                    }
                                                                }
                                                            }         
                                                            
                                                            TextEditor(text: $infoArray[index])
                                                                .overlay {
                                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                        .stroke(Color(hexadecimal: descriptionColor), lineWidth: 2)
                                                                    
                                                                }
                                                            //  .multilineTextAlignment(.center)
                                                            
                                                                .foregroundStyle(Color(hexadecimal: descriptionColor))
                                                            
                                                                .onChange(of: infoArray[index]) {
                                                                    
                                                                    if infoArray[index] == "" {
                                                                        Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { timer in
                                                                            if infoArray[index] == "" {
                                                                                infoArray[index] = " "
                                                                            }
                                                                        }
                                                                    }
                                                                    if infoArray[index] == " " {
                                                                        bigDic[currentTab]!["description"] = infoArray
                                                                        UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                    }
                                                                    if subjects[index] == " " {
                                                                        subjects[index] = "Enter new value"
                                                                        Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { timer in
                                                                            if subjects[index] == "Enter new value" {
                                                                                subjects[index] = " "
                                                                            }
                                                                        }
                                                                    }
                                                                    bigDic[currentTab]!["subjects"] = subjects
                                                                    bigDic[currentTab]!["description"] = infoArray
                                                                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                }
                                                                .onSubmit {
                                                                    if infoArray[index] == "Enter new value" {
                                                                        infoArray[index] = " "
                                                                    }
                                                                    if subjects[index] == "Enter new value" {
                                                                        subjects[index] = " "
                                                                    }
                                                                    bigDic[currentTab]!["subjects"] = subjects
                                                                    bigDic[currentTab]!["description"] = infoArray
                                                                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                }
                                                            
                                                            
                                                                .font(.title3)
                                                                .padding()
                                                            
                                                            
                                                            
                                                        }
                                                        //  .offset(x:-15)
                                                        .padding()
                                                        //  .frame(maxWidth: infoArray[index] != " " ? screenWidth/2 : 0)
                                                        .frame(maxWidth: infoArray[index] != " " ? screenWidth/3 : 0, maxHeight: screenHeight/5)
                                                        .fixedSize(horizontal: false,vertical: true)
                                                        
                                                    }
                                                    
                                                    // subject picker and textfield
                                                    if subjects[index] != " " {
                                                        Spacer(minLength: 0)
                                                        HStack {
                                                            if subjectPicker {
                                                                Button {
                                                                    pickerOpen.toggle()
                                                                } label : {
                                                                    ZStack {
                                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                            .stroke(Color(hexadecimal: subjectColor), lineWidth: 2)
                                                                            .frame(width: 30, height: 38)
                                                                            .background(Color(hexadecimal: subjectColor).opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                                        
                                                                        
                                                                        Image(systemName: "book.closed")
                                                                            .foregroundStyle(Color(hexadecimal: subjectColor))
                                                                            .shadow(color: .gray, radius: 5, x: 0, y: 0)
                                                                        
                                                                    }   
                                                                }
                                                                Picker("\(subjects[index])", selection: $subjects[index]) {
                                                                    Section(header: Text("Common Subjects")) {
                                                                        ForEach(commonSub, id:\.self) { i in
                                                                            Text(i).tag(i)
                                                                        }
                                                                    }
                                                                    ForEach(allSubjects.keys.sorted(), id: \.self) { tab in
                                                                        if tab.lowercased().hasSuffix(" list") {
                                                                            Section(header: Text("\(tab)")) {
                                                                                if let subjectsInTab = allSubjects[tab] {
                                                                                    ForEach(Array(Set(subjectsInTab)), id: \.self) { chosenSubject in
                                                                                        let count = subjectsInTab.filter { $0 == chosenSubject }.count
                                                                                        if count > 1 {
                                                                                            
                                                                                            Text("\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject") (\(count))")
                                                                                                .tag(chosenSubject)
                                                                                            
                                                                                        } else {
                                                                                            
                                                                                            Text("\(noSpace(string: chosenSubject) != "" ?  chosenSubject : "Empty Subject")")
                                                                                                .tag(chosenSubject)
                                                                                            
                                                                                            
                                                                                            
                                                                                            
                                                                                        }
                                                                                        
                                                                                        
                                                                                    }
                                                                                }
                                                                            }
                                                                            
                                                                        }
                                                                    }
                                                                }
                                                                
                                                                .scaleEffect(pickerOpen ? 1.0 : 0.0)
                                                                .frame(maxWidth: pickerOpen ? screenWidth/4 : 0 )
                                                                .fixedSize(horizontal: true, vertical: false)
                                                                .onChange(of: subjects[index]) {
                                                                    bigDic[currentTab]!["subjects"] = subjects
                                                                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                }
                                                            }
                                                            TextField("\(subjects[index])".trimmingCharacters(in: .whitespacesAndNewlines), text: $subjects[index])
                                                                .textFieldStyle(subjectPicker ? RoundedTextFieldStyle(iconColor: Color(hexadecimal: subjectColor)) : RoundedTextFieldStyle(icon: Image(systemName: "book.closed"), iconColor: Color(hexadecimal: subjectColor)))
                                                            // .textFieldStyle(RoundedTextFieldStyle(iconColor: Color(hexadecimal: subjectColor)))
                                                                .onChange(of: subjects[index]) {
                                                                    
                                                                    if infoArray[index] == " " {
                                                                        infoArray[index] = "Enter new value"
                                                                        Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { timer in
                                                                            if infoArray[index] == "Enter new value" {
                                                                                infoArray[index] = " "
                                                                                bigDic[currentTab]!["description"] = infoArray
                                                                                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                            }
                                                                        }
                                                                    }
                                                                    if subjects[index] == "" {
                                                                        Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { timer in
                                                                            if subjects[index] == "" {
                                                                                subjects[index] = " "
                                                                                bigDic[currentTab]!["subjects"] = subjects
                                                                                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                            }
                                                                        }
                                                                    }
                                                                    
                                                                    if subjects[index] == " " {
                                                                        bigDic[currentTab]!["subjects"] = subjects
                                                                        UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                    }
                                                                    
                                                                    bigDic[currentTab]!["subjects"] = subjects
                                                                    bigDic[currentTab]!["description"] = infoArray
                                                                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                    
                                                                }
                                                            
                                                                .onSubmit {
                                                                    if infoArray[index] == "Enter new value" {
                                                                        infoArray[index] = " "
                                                                    }
                                                                    if subjects[index] == "Enter new value" {
                                                                        subjects[index] = " "
                                                                    }
                                                                    bigDic[currentTab]!["subjects"] = subjects
                                                                    bigDic[currentTab]!["description"] = infoArray
                                                                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                                                }
                                                                .font(.title2)
                                                            
                                                        }
                                                        .tint(Color(hexadecimal: subjectColor))
                                                        .foregroundStyle(Color(hexadecimal: subjectColor))
                                                        .padding()
                                                        .frame(maxWidth: subjects[index] != " " ? (infoArray[index] != " " ? screenWidth/3 : screenWidth/2) : 0)
                                                        .fixedSize(horizontal: true, vertical: false)
                                                    }
                                                    //      .offset(y: -25)
                                                }
                                                //.offset(x: 100)
                                                
                                                Divider()
                                                //   .offset(x: 50)
                                                    .frame(maxWidth: screenWidth/1.2, alignment: .leading)   
                                                
                                                // dates
                                                HStack {
                                                    
                                                    
                                                    DatePicker(selection: $dueDates[index], displayedComponents: [.hourAndMinute, .date], label: {
                                                        Text("Due: ")
                                                    })
                                                    .onChange(of: dueDates) {
                                                        dueDic[currentTab]! = dueDates
                                                        UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                                    }
                                                    .datePickerStyle(.compact)
                                                    .padding()
                                                    .fixedSize()
                                                    
                                                    
                                                    Spacer()
                                                    Text("Created: \(dates[index])")
                                                }
                                            }
                                            
                                        }
                                    }
                                    .padding(20)
                                }
                                .padding(7.5)
                                .onAppear {
                                    if hasAppeared == false{
                                        
                                        if infoArray[index] == "Enter new value" {
                                            infoArray[index] = " "
                                        }
                                        if subjects[index] == "Enter new value" {
                                            subjects[index] = " "
                                        }
                                        bigDic[currentTab]!["subjects"] = subjects
                                        bigDic[currentTab]!["description"] = infoArray
                                        UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                        
                                        hasAppeared = true
                                    }
                                    
                                }
                                .strikethrough(selectDelete[index])   
                                .animation(.bouncy(duration: 1))
                                
                            }
                            .foregroundStyle(.blue)
                            .padding(10)
                            
                            
                            
                        }
                        //     .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 1.0))
                        .animation(.bouncy(duration: 1))
                        .offset(y:-25)
                        .defaultScrollAnchor(infoArray.count > 2 ? .bottom : .top)
                        
                        // the editing tab
                    } else if currentTab == "+erder" {
                        HStack {
                            VStack {
                                Image(systemName: "minus")
                                    .frame(width: 50, height: 25)
                                    .background(.brown, in: RoundedRectangle(cornerRadius: 10))
                                
                                Divider()
                                
                                Picker("Delete",selection: $deleteTabs) {
                                    ForEach(Array(bigDic.keys), id: \.self) { i in
                                        if i.lowercased().hasSuffix(" list") {
                                            Text(i).tag(i)
                                        }
                                    }
                                }
                                .pickerStyle(.automatic)
                                
                                
                                Button {
                                    if deleteTabs != "Basic List" {
                                        bigDic.removeValue(forKey: deleteTabs)
                                        dueDic.removeValue(forKey: deleteTabs)
                                        
                                        UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                        UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                    } else {
                                        deleteWarning = true
                                    }
                                    
                                } label: {
                                    Text("Delete List")
                                }
                                
                            }
                            .alert("CAN NOT DELETE STARTER LIST", isPresented: $deleteWarning) {
                                Button("Ok"){}
                            }
                            
                            Divider()
                            
                            VStack {
                                Image(systemName: "plus")
                                    .frame(width: 50, height: 25)
                                    .background(.brown, in: RoundedRectangle(cornerRadius: 10))
                                
                                Divider()
                                
                                TextField("New List Name", text: $createTab)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    if bigDic.keys.contains(createTab) || bigDic.keys.contains("\(createTab) List") {
                                        addWarning = true
                                        
                                    } else {
                                        
                                        if createTab.lowercased().hasSuffix(" list") {
                                            bigDic["\(createTab)"] = [
                                                "subjects": [],
                                                "names": [],
                                                "description": [],
                                                "date": []
                                            ]
                                            
                                            dueDic["\(createTab)"] = []
                                            
                                            UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                            UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                            
                                        } else {
                                            if createTab != "" {
                                                bigDic["\(createTab) List"] = [
                                                    "subjects": [],
                                                    "names": [],
                                                    "description": [],
                                                    "date": []
                                                ]
                                                
                                                dueDic["\(createTab) List"] = []
                                            }
                                            UserDefaults.standard.set(bigDic, forKey: "DicKey")
                                            UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                                        }
                                    }
                                    createTab = ""
                                } label: {
                                    Text("Submit Name")
                                }
                            }
                            .alert("Already An Existing Name!", isPresented: $addWarning) {
                                Button("Ok"){}
                            }
                            
                            
                        }
                        .fixedSize()
                        
                    }
                }
                Spacer()    
            }
            
        }
        .onAppear {
            deleted = false 
            if currentTab == "+erder" {
                currentTab = "Basic List"
            }
            
            retrieveBigDic = UserDefaults.standard.dictionary(forKey: "DicKey") as? [String: [String: [String]]] ?? [:]
            
            bigDic = (retrieveBigDic[currentTab]?["subjects"] != nil ? retrieveBigDic : bigDic )
            
            retrieveDueDic = UserDefaults.standard.dictionary(forKey: "DueDicKey") as? [String : [Date]] ?? [:]
            
            dueDic = (retrieveDueDic[currentTab] != nil ? retrieveDueDic : dueDic)
            print("\(bigDic)")
            names = bigDic[currentTab]!["names"]!
            subjects = bigDic[currentTab]!["subjects"]!
            infoArray = bigDic[currentTab]!["description"]!
            dates = bigDic[currentTab]!["date"]!
            dueDates = dueDic[currentTab]!
            
            for tab in bigDic.keys {
                allSubjects[tab] = []
                if tab.lowercased().hasSuffix(" list") {
                    if let subjects = bigDic[tab]?["subjects"] as? [String] {
                        allSubjects[tab] = subjects
                    }
                }
            }
            print(allSubjects)
            
            selectDelete = []
            for _ in 0..<infoArray.count {
                selectDelete.append(false)
            }
            DateFormatter().dateFormat = "M/d/yyyy, h:mm a"
            
            if bigDic[currentTab]?["description"] != [] && bigDic[currentTab]?["description"] != [String()] {
                var sortedIndices = dates.indices.sorted(by: { dates[$0] > dates[$1] })
                
                if organizedAssignments == "Due By Descending (Recent to Oldest)"{
                    sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] < dueDates[$1] })
                    
                } else if organizedAssignments == "Due By Ascending (Oldest to Recent)" {
                    sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] > dueDates[$1] })
                    
                } else if organizedAssignments == "Created By Descending (Recent to Oldest)"{
                    sortedIndices = dates.indices.sorted(by: { dates[$0] > dates[$1] })
                    
                } else if organizedAssignments == "Created By Ascending (Oldest to Recent)"  {
                    sortedIndices = dates.indices.sorted(by: { dates[$0] < dates[$1] })
                }
                
                subjects = sortedIndices.map { bigDic[currentTab]!["subjects"]![$0] }
                names = sortedIndices.map { bigDic[currentTab]!["names"]![$0] }
                infoArray = sortedIndices.map { bigDic[currentTab]!["description"]![$0] }
                dates = sortedIndices.map { bigDic[currentTab]!["date"]![$0] }
                dueDates = sortedIndices.map { dueDic[currentTab]![$0] }
                selectDelete = sortedIndices.map { selectDelete[$0]}
                
                bigDic[currentTab]!["subjects"] = subjects
                bigDic[currentTab]!["description"] = infoArray
                bigDic[currentTab]!["names"] =  names
                bigDic[currentTab]!["date"] = dates
                dueDic[currentTab]! = dueDates 
                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                caughtUp = false 
            } else {
                caughtUp = true
            }
            error = false
            loadedData = true
            
            if selectedTab == 0 {
                for index in infoArray.indices {
                    if infoArray[index] == "Enter new value" {
                        infoArray[index] = " "
                        bigDic[currentTab]!["description"] = infoArray
                    }
                    if subjects[index] == "Enter new value" {
                        subjects[index] = " "
                        bigDic[currentTab]!["subjects"] = subjects
                        
                        
                    }
                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                }
            }
        }
        .onChange(of: selectedTab) {
            deleted = false 
            if currentTab == "+erder" {
                currentTab = "Basic List"
            }
            
            retrieveBigDic = UserDefaults.standard.dictionary(forKey: "DicKey") as? [String: [String: [String]]] ?? [:]
            
            bigDic = (retrieveBigDic[currentTab]?["subjects"] != nil ? retrieveBigDic : bigDic )
            
            retrieveDueDic = UserDefaults.standard.dictionary(forKey: "DueDicKey") as? [String : [Date]] ?? [:]
            
            dueDic = (retrieveDueDic[currentTab] != nil ? retrieveDueDic : dueDic)
            print("\(bigDic)")
            names = bigDic[currentTab]!["names"]!
            subjects = bigDic[currentTab]!["subjects"]!
            infoArray = bigDic[currentTab]!["description"]!
            dates = bigDic[currentTab]!["date"]!
            dueDates = dueDic[currentTab]!
            
            for tab in bigDic.keys {
                allSubjects[tab] = []
                if tab.lowercased().hasSuffix(" list") {
                    if let subjects = bigDic[tab]?["subjects"] as? [String] {
                        allSubjects[tab] = subjects
                    }
                }
            }
            print(allSubjects)
            
            selectDelete = []
            for _ in 0..<infoArray.count {
                selectDelete.append(false)
            }
            DateFormatter().dateFormat = "M/d/yyyy, h:mm a"
            
            if bigDic[currentTab]?["description"] != [] && bigDic[currentTab]?["description"] != [String()] {
                var sortedIndices = dates.indices.sorted(by: { dates[$0] > dates[$1] })
                
                if organizedAssignments == "Due By Descending (Recent to Oldest)"{
                    sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] < dueDates[$1] })
                    
                } else if organizedAssignments == "Due By Ascending (Oldest to Recent)" {
                    sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] > dueDates[$1] })
                    
                } else if organizedAssignments == "Created By Descending (Recent to Oldest)"{
                    sortedIndices = dates.indices.sorted(by: { dates[$0] > dates[$1] })
                    
                } else if organizedAssignments == "Created By Ascending (Oldest to Recent)"  {
                    sortedIndices = dates.indices.sorted(by: { dates[$0] < dates[$1] })
                }
                
                subjects = sortedIndices.map { bigDic[currentTab]!["subjects"]![$0] }
                names = sortedIndices.map { bigDic[currentTab]!["names"]![$0] }
                infoArray = sortedIndices.map { bigDic[currentTab]!["description"]![$0] }
                dates = sortedIndices.map { bigDic[currentTab]!["date"]![$0] }
                dueDates = sortedIndices.map { dueDic[currentTab]![$0] }
                selectDelete = sortedIndices.map { selectDelete[$0]}
                
                bigDic[currentTab]!["subjects"] = subjects
                bigDic[currentTab]!["description"] = infoArray
                bigDic[currentTab]!["names"] =  names
                bigDic[currentTab]!["date"] = dates
                dueDic[currentTab]! = dueDates 
                UserDefaults.standard.set(bigDic, forKey: "DicKey")
                UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                caughtUp = false 
            } else {
                caughtUp = true
            }
            error = false
            loadedData = true
            
            if selectedTab == 0 {
                for index in infoArray.indices {
                    if infoArray[index] == "Enter new value" {
                        infoArray[index] = " "
                        bigDic[currentTab]!["description"] = infoArray
                    }
                    if subjects[index] == "Enter new value" {
                        subjects[index] = " "
                        bigDic[currentTab]!["subjects"] = subjects
                        
                        
                    }
                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                }
            }
        }
        .onChange(of: currentTab) {
            deleted = false  
            if currentTab != "+erder" {
                retrieveBigDic = UserDefaults.standard.dictionary(forKey: "DicKey") as? [String: [String: [String]]] ?? [:]
                retrieveDueDic = UserDefaults.standard.dictionary(forKey: "DueDicKey") as? [String : [Date]] ?? [:]
                
                bigDic = (retrieveBigDic[currentTab]?["subjects"] != nil ? retrieveBigDic : bigDic )
                dueDic = (retrieveDueDic[currentTab] != nil ? retrieveDueDic : dueDic)
                
                names = bigDic[currentTab]!["names"]!
                subjects = bigDic[currentTab]!["subjects"]!
                infoArray = bigDic[currentTab]!["description"]!
                dates = bigDic[currentTab]!["date"]!
                dueDates = dueDic[currentTab]!
                
                selectDelete = []
                selectDelete = Array(repeating: false, count: infoArray.count)
                
                DateFormatter().dateFormat = "M/d/yyyy, h:mm a"
                
                if bigDic[currentTab]?["description"] != [] && bigDic[currentTab]?["description"] != [String()] {
                    
                    var sortedIndices = dates.indices.sorted(by: { dates[$0] > dates[$1] })
                    
                    if organizedAssignments == "Due By Descending (Recent to Oldest)"{
                        sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] < dueDates[$1] })
                        
                    } else if organizedAssignments == "Due By Ascending (Oldest to Recent)" {
                        sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] > dueDates[$1] })
                        
                    } else if organizedAssignments == "Created By Descending (Recent to Oldest)"{
                        sortedIndices = dates.indices.sorted(by: { dates[$0] > dates[$1] })
                        
                    } else if organizedAssignments == "Created By Ascending (Oldest to Recent)"  {
                        sortedIndices = dates.indices.sorted(by: { dates[$0] < dates[$1] })
                    }
                    
                    subjects = sortedIndices.map { bigDic[currentTab]!["subjects"]![$0] }
                    names = sortedIndices.map { bigDic[currentTab]!["names"]![$0] }
                    infoArray = sortedIndices.map { bigDic[currentTab]!["description"]![$0] }
                    dates = sortedIndices.map { bigDic[currentTab]!["date"]![$0] }
                    dueDates = sortedIndices.map { dueDic[currentTab]![$0] }
                    selectDelete = sortedIndices.map { selectDelete[$0]}
                    
                    bigDic[currentTab]!["subjects"] = subjects
                    bigDic[currentTab]!["description"] = infoArray
                    bigDic[currentTab]!["names"] =  names
                    bigDic[currentTab]!["date"] = dates
                    dueDic[currentTab]! = dueDates 
                    UserDefaults.standard.set(bigDic, forKey: "DicKey")
                    UserDefaults.standard.set(dueDic, forKey: "DueDicKey")
                    caughtUp = false    
                    
                } else {
                    caughtUp = true
                }
                
                error = false
                loadedData = true
                
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
    @State var color : Color?
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
    @State var iconColor : Color?
    
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
          let day = components.day else {
        print("Error: Unable to get current date components.")
        return 0
    }
    
    // combine today's date with the given time
    let fullDateString = "\(year)-\(month)-\(day) \(timeString)"
    let dateTimeStringFormatter = DateFormatter()
    dateTimeStringFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    
    // makes sure that it does not return a nil
    guard let targetDate = dateTimeStringFormatter.date(from: fullDateString) else {
        print("Error: Unable to parse time string '\(fullDateString)'.")
        return 0
    }
    
    let secondsUntilTargetDate = Int(targetDate.timeIntervalSince(now))
    
    return secondsUntilTargetDate
}

func noSpace(string: String) -> String {
    return string.trimmingCharacters(in: .whitespaces)
    
}
