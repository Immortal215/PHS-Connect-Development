import SwiftUI
import Pow
import Drops
struct Homepage: View {
    @State var screenWidth = UIScreen.main.bounds.width
    @State var screenHeight = UIScreen.main.bounds.height
    
    @AppStorage("completed") var completed = 0
    
    @AppStorage("currentTab") var currentTab = "Basic List"
    @State var retrieveBigDic: [String: [String: [String]]] = UserDefaults.standard.dictionary(forKey: "DicKey") as? [String: [String: [String]]] ?? ["Basic List": ["subjects": [String()], "names": [String()], "description": [String()], "date": [String()]]]
    @State var bigDic: [String: [String: [String]]] = ["Basic List": ["subjects": [String()], "names": [String()], "description": [String()], "date": [String()]]]
    
    @State var retrieveDueDic: [String: [Date]] = UserDefaults.standard.dictionary(forKey: "DueDicKey") as? [String: [Date]] ?? ["Basic List": [Date()]]
    @State var dueDic: [String: [Date]] = ["Basic List": [Date()]]
    
    @State var retrieveSubjectsArray: [String] = UserDefaults.standard.array(forKey: "subjects") as? [String] ?? []
    @State var subjects: [String] = []
    
    @State var names: [String] = []
    
    @State var retrieveInfoArray: [String] = UserDefaults.standard.array(forKey: "description") as? [String] ?? []
    @State var infoArray: [String] = []
    
    @State var retrieveDateArray: [String] = UserDefaults.standard.array(forKey: "date") as? [String] ?? []
    @State var dates: [String] = []
    
    @State var retrieveDueArray: [Date] = UserDefaults.standard.array(forKey: "due") as? [Date] ?? []
    @State var dueDates: [Date] = []
    
    @State var daterio: [Date] = [Date()]
    
    @State var description = ""
    @State var name = ""
    @State var subject = ""
    @State var date = ""
    @AppStorage("thoughts") var thoughtText = ""
    @State var lastValue = ""
    
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
    @State var notificationer = false
    @State var foregroundStyle = Color.green
    @State var thoughtsOpened = false
    @AppStorage("selectedTab") var selectedTab = 1
    @AppStorage("urgentCount") var urgentCount = 3
    
    // draw stuff
    @State var lines: [Line] = []
    @State var currentLine: Line = Line(points: [])
    @AppStorage("chosenWidth") var chosenWidth = 5.0
    @State var drawOpened = false
    
    // time stuff
    @AppStorage("pomotimer") var pomoTime = 1500
    @AppStorage("breakTime") var breakTime = 300
    @AppStorage("breaks") var breaks = 4
    @AppStorage("pomoOpened") var pomoOpened = false
    @AppStorage("opened") var opened = false
    @AppStorage("breakText") var breakText = false
    @AppStorage("currentBreaks") var currentBreaks = 0
    
    var hours: String {
        let time = (progressTime % 216000) / 3600
        return time < 10 ? "0\(time)" : "\(time)"
    }
    
    var minutes: String {
        
        let time = (progressTime % 3600) / 60
        return time < 10 ? "0\(time)" : "\(time)"
    }
    
    var seconds: String {
        
        let time = progressTime % 60
        return time < 10 ? "0\(time)" : "\(time)"
    }
    
    @AppStorage("progressTime") var progressTime = 0
    @AppStorage("timered") var timered = false
    @AppStorage("timeredStart") var timeredStart = false
    @AppStorage("alarmLevel") var alarmLevel = "myalarm.mp3"
    
    var timerPomo: Timer {
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timered != true || timeredStart != true {
                if progressTimePomo > 0 {
                    progressTimePomo -= 1
                } else if progressTimePomo == 0 {
                    if breakText == false {
                        breakText = true
                        progressTimePomo = breakTime
                        currentBreaks += 1
                    } else {
                        breakText = false
                        progressTimePomo = pomoTime
                    }
                    
                }
            }
            
            if timered == true {
                stopTimer()
                timered = false
            }
            if timeredStart == true {
                startTimer()
                timeredStart = false
            }
        }
    }
    func stopTimer() {
        timerPomo.invalidate()
        myTimerPomo?.invalidate()
    }
    
    func startTimer() {
        timerPomo.invalidate()
        myTimerPomo?.invalidate()
        myTimerPomo = timerPomo
    }
    var minutesPomo: String {
        let time = progressTimePomo % 3600 == 0 ? 60 : (progressTimePomo % 3600) / 60
        return time < 10 ? "0\(time)" : "\(time)"
    }
    
    var secondsPomo: String {
        let time = progressTimePomo % 60
        return time < 10 ? "0\(time)" : "\(time)"
    }
    
    @AppStorage("progressPomo") var progressTimePomo = 0
    @State var myTimerPomo:Timer?
    @AppStorage("subjectcolor") var subjectColor: String = "#91E2FD"
    @AppStorage("titlecolor") var titleColor: String = "#E2FFC2"
    @AppStorage("descolor") var descriptionColor: String = "#FFFFFF"
    @AppStorage("cornerRadius") var cornerRadius = 300
    @AppStorage("drawer") var drawer = true 
    @AppStorage("writer") var writer = true 
    var body: some View {
        ZStack {
            
            
            VStack {
                Text("Home")
                    .font(.title)
                    .fontWeight(.semibold)
                
                HStack {
                    // planner
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .foregroundColor(.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(.white, lineWidth: 3)
                                    
                                )
                                .shadow(radius: 5)
                            
                            HStack {
                                
                                NumberView()
                                    .clipShape(Circle())
                                    .frame(width: 30, height: 30)
                                    .changeEffect(
                                        .rise(origin: UnitPoint(x: 0.75, y: 0.25)) {
                                            Text("+1")
                                                .foregroundStyle(Color(hue: Double(completed % 360) / 360.0, saturation: 0.5, brightness: 0.9))
                                    }, value: completed) 
                                
                                    .overlay {
                                        Circle()
                                            .stroke(.white, lineWidth: 3)
                                            .frame(width: 39, height: 39)
                                    }
                                
                                
                                Text("Most Urgent!")
                                    .font(.title2)
                                    .padding(.horizontal)
                                
                                Button {
                                    selectedTab = 1
                                } label : {
                                    
                                    Image(systemName: "arrow.up.forward.app")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                }
                                
                            }
                            .padding()
                        }
                        .fixedSize()
                        
                        Picker("", selection: $currentTab) {
                            ForEach(Array(bigDic.keys), id: \.self) { i in
                                if i.lowercased().hasSuffix(" list") {
                                    Text("\(i) (\(bigDic[i]!["names"]!.count))").tag(i)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                        
                       // Divider()
                            .frame(width: 400)
                        
                        Button {
                            selectedTab = 1
                        } label : {
                            HStack {
                                Text(caughtUp ? "Add Objectives!" : "")
                                    .font(.title)
                                    .fixedSize()
                                
                                Image(systemName: "arrow.up.forward.app")
                                    .resizable()
                                    .frame(width: caughtUp ? 20 : 0, height: caughtUp ? 20 : 0)
                            }
                            
                            
                        }
                        .padding(caughtUp ? 30 : 0)
                        
                        // assignments
                        if loadedData && bigDic[currentTab]?["description"]?.isEmpty != true && caughtUp == false && infoArray.count != 0 {
                            
                            ScrollView {
                                ForEach(0..<(urgentCount != 0 ? min(urgentCount, infoArray.count) : infoArray.count), id: \.self) { index in
                                    Spacer()
                                    
                                    ZStack {
                                        
                                        RoundedRectangle(cornerRadius: 25)
                                            .foregroundStyle(.black)  
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 25)
                                                    .stroke(.white, lineWidth: 3)
                                                    .frame(width: screenWidth/2.1)
                                            )
                                            .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 4)   
                                            .frame(width: screenWidth/2.1)
                                        
                                        VStack {
                                            HStack {
                                                Text("")
                                                    .overlay(
                                                        Image(systemName: selectDelete[index] ? "checkmark.circle.fill" : "checkmark")
                                                            .resizable()
                                                            .frame(width: deleted ? 0 : 75, height: deleted ? 0 : 75, alignment: .center)
                                                            .scaleEffect(selectDelete[index] ? 1.0 : 0.5)
                                                            .foregroundStyle(selectDelete[index] ? 
                                                                .red.opacity(0.9) :  
                                                                .blue.opacity(0.85)) 
                                                            .blur(radius: 0.5)    
                                                    )
                                                    .frame(width:0, height:0)
                                                    .animation(.snappy())
                                                    .onHover { hovering in
                                                        if hovering {
                                                            selectDelete[index] = true
                                                        } else {
                                                            selectDelete = Array(repeating: false, count: infoArray.count)
                                                        }
                                                    }
                                                    .offset(x: -50)
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
                                                
                                                VStack {
                                                    let gradientTitle = LinearGradient(stops: [
                                                        .init(color: Color(hexadecimal: subjectColor).opacity(0.95), location: 0.0),
                                                        .init(color: Color(hexadecimal: titleColor).opacity(0.95), location: 0.5),
                                                        .init(color: Color(hexadecimal: descriptionColor).opacity(0.95), location: 1.0),
                                                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    
                                                    let gradientSubject = LinearGradient(stops: [
                                                        .init(color: Color(hexadecimal: titleColor).opacity(0.95), location: 0.0),
                                                        .init(color: Color(hexadecimal: subjectColor).opacity(0.95), location: 0.5),
                                                        .init(color: Color(hexadecimal: descriptionColor).opacity(0.95), location: 1.0),
                                                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    
                                                    let gradientDescription = LinearGradient(stops: [
                                                        .init(color: Color(hexadecimal: subjectColor).opacity(0.95), location: 0.0),
                                                        .init(color: Color(hexadecimal: descriptionColor).opacity(0.95), location: 0.5),
                                                        .init(color: Color(hexadecimal: titleColor).opacity(0.95), location: 1.0),
                                                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    
                                                    HStack {
                                                        Text(names[index].trimmingCharacters(in: .whitespacesAndNewlines))
                                                            .foregroundStyle(Color(hexadecimal: titleColor))
                                                            .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 1)  
                                                            .font(.title2.bold())  
                                                            .frame(maxWidth: subjects[index] != " " ? screenWidth/6 : screenWidth/4, maxHeight: 100)
                                                        
                                                        if subjects[index] != " " {
                                                            Divider()
                                                                .frame(height: 30)  
                                                                .opacity(0.7)      
                                                            
                                                            Text(subjects[index].trimmingCharacters(in: .whitespacesAndNewlines))
                                                                .foregroundStyle(Color(hexadecimal: subjectColor))
                                                                .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 1)  
                                                                .font(.title2)
                                                                .frame(maxWidth: screenWidth/6, maxHeight: 100)
                                                        }
                                                    }
                                                    
                                                    if infoArray[index] != " " {
                                                        Divider()
                                                            .frame(maxWidth: screenWidth/4)
                                                            .opacity(0.7)  
                                                    }
                                                    
                                                    VStack {
                                                        if infoArray[index] != " " {
                                                            ScrollView { 
                                                                Text(infoArray[index].trimmingCharacters(in: .whitespacesAndNewlines))
                                                                    .foregroundStyle(Color(hexadecimal: descriptionColor))
                                                                    .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: 1)  
                                                                    .font(.title2)
                                                                    .frame(alignment: .leading)
                                                            }
                                                            .frame(maxWidth: screenWidth/3, maxHeight: screenHeight/8)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                        }
                                                        
                                                        Divider()
                                                            .frame(maxWidth: screenWidth/3)
                                                            .opacity(0.7) 
                                                        
                                                        Text("Due : \(dateFormatClean(str: dueDates[index]))")
                                                            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: 1)  
                                                            .fixedSize()
                                                    }
                                                }
                                            }
                                        }
                                        .foregroundStyle(foregroundStyler(dueDate: dueDates[index], assignment: names[index]))
                                        .onChange(of: dueDates[index]) {
                                            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                                                if dueDates.count < index {
                                                    foregroundStyle = foregroundStyler(dueDate: dueDates[index], assignment: names[index])
                                                }
                                            }
                                            styleNotification(dueDate: dueDates[index], assignment: names[index], description: infoArray[index], alarm: alarmLevel)
                                        }
                                        .offset(x: 25)
                                        .frame(width: screenWidth/2)
                                        .padding(10)
                                    }
                                    .padding(7.5)
                                    .strikethrough(selectDelete[index])
                                    .opacity(selectDelete[index] ? 0.7 : 1.0)
                                    .saturation(selectDelete[index] ? 0.7 : 1.0)
                                }
                                

                            }
                            .animation(.bouncy(duration: 1))
                        }
                        Spacer()
                    }
                    .frame(width: screenWidth/2)
                    
                    // timer/draw/thoughts
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .foregroundColor(.black)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(.white, lineWidth: 3)
                                    //    .frame(width: screenWidth/4.3)
                                    
                                }
                                .shadow(radius: 5)
                            //   .frame(width: screenWidth/4.3)
                            
                            HStack {
                                Text("Timers!")
                                    .font(.title2)
                                    .padding(.trailing)
                                
                                Button {
                                    selectedTab = 2
                                } label : {
                                    
                                    Image(systemName: "arrow.up.forward.app")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                }
                            }
                            .padding()
                        }
                        .fixedSize()
                        
                      //  Divider()
                          //  .frame(width: 400)
                        
                        Button {
                            selectedTab = 2
                        } label : {
                            HStack {
                                Text(progressTimePomo == pomoTime && progressTime == 0 ? "No Timers Set!" : "")
                                    .font(.title)
                                    .fixedSize()
                                
                                Image(systemName: "arrow.up.forward.app")
                                    .resizable()
                                    .frame(width: progressTimePomo == pomoTime && progressTime == 0 ? 20 : 0, height: progressTimePomo == pomoTime && progressTime == 0 ? 20 : 0)
                            }
                            
                            
                        }
                        
                        .animation(.snappy(duration: 0.3, extraBounce: 0.3))
                        
                        VStack {
                            ScrollView {
                                if progressTime != 0 {
                                    HStack {
                                        Text("Stop Watch")
                                        
                                        Divider()
                                        
                                        Text("\(hours):\(minutes):\(seconds)")
                                        
                                    }
                                    .font(.system(size: 25))
                                    .fixedSize()
                                }
                                if progressTimePomo != pomoTime {
                                    HStack {
                                        Text("\(breakText ? "Break" : "Pomodoro") Timer")
                                            .fixedSize()
                                            .padding()
                                        
                                        
                                        ZStack {
                                            
                                            RoundedRectangle(cornerRadius: CGFloat(cornerRadius/3))
                                                .stroke(lineWidth: 10)
                                                .opacity(0.3)
                                                .foregroundColor(.gray)
                                                .animation(.linear(duration: 1))
                                                .frame(width:100, height:100)
                                            
                                            RoundedRectangle(cornerRadius: CGFloat(cornerRadius/3))
                                                .trim(from: 0.0, to: CGFloat(breakText ? Double(progressTimePomo)/Double(breakTime) : Double(progressTimePomo)/Double(pomoTime)))
                                                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                                                .rotationEffect(Angle(degrees: -90.0))
                                                .animation(.linear(duration: 1))
                                                .foregroundStyle(breakText ? .green : .pink)
                                                .opacity(0.3)
                                                .frame(width:100, height:100)
                                            
                                            Text("\(minutesPomo):\(secondsPomo)")
                                                .frame(width:100, height:50)
                                                .padding()
                                        }
                                        .padding()
                                        
                                        HStack {
                                            Button {
                                                if timeredStart != true {
                                                    timeredStart = true
                                                    startTimer()
                                                }
                                                
                                            } label: {
                                                Text("Start")
                                                    .font(.callout)
                                                    .foregroundStyle(.black)
                                                    .animation(.bouncy(duration: 1, extraBounce: 0.1))
                                                
                                            }
                                            .padding(5)
                                            .buttonStyle(ChunkyButton(color: .green))
                                            .fixedSize()
                                            .offset(x:-10)
                                            
                                            Button {
                                                timered = true
                                                stopTimer()
                                                
                                            } label: {
                                                Text("Stop")
                                                    .font(.callout)
                                                    .foregroundStyle(.black)
                                                    .animation(.bouncy(duration: 1, extraBounce: 0.1))
                                                
                                            }
                                            .padding(5)
                                            .buttonStyle(ChunkyButton(color: .red))
                                            .fixedSize()
                                            
                                        }
                                    }
                                    .font(.system(size:25))
                                    .fixedSize()
                                }
                                
                                // thought text
                                if writer {
                                    VStack {
                                        HStack {
                                            
                                            Button {
                                                let originalThoughtText = thoughtText
                                                thoughtText = thoughtText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                
                                                if thoughtText == originalThoughtText {
                                                    thoughtText = ""
                                                    thoughtsOpened = false
                                                }
                                            } label: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(.white, lineWidth: 2)
                                                        .frame(width: 30, height: 38)
                                                        .background(.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    
                                                    
                                                    Image(systemName: "archivebox")
                                                        .foregroundColor(.white)
                                                        .shadow(color: .gray, radius: 5, x: 0, y: 0)
                                                }
                                            }
                                            .padding()
                                            .scaleEffect( thoughtsOpened ? 1.0 : 0 )
                                            .frame(maxWidth: thoughtsOpened ? .infinity : 0)
                                            .fixedSize()
                                            
                                            ZStack {
                                                if thoughtText.isEmpty {
                                                    Text("Add Thoughts While Working!")
                                                        .foregroundColor(.gray)
                                                        .font(.title3)
                                                }
                                                
                                                TextEditor(text: $thoughtText)
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .stroke(.white, lineWidth: 3)
                                                        
                                                    }
                                                    .multilineTextAlignment(.leading)
                                                    .foregroundStyle(.white)
                                                    .frame(maxWidth: thoughtsOpened ? screenWidth/2.3 : screenWidth/2.1, maxHeight: screenHeight/7)
                                                    .scrollContentBackground(.hidden)
                                                    .font(.title3)
                                                    .padding()
                                                    .onChange(of: thoughtText) {
                                                        if thoughtText != "" {
                                                            thoughtsOpened = true
                                                        } else {
                                                            thoughtsOpened = false
                                                        }
                                                        
                                                        if thoughtText.last == "\n" && lastValue != "-" {
                                                            thoughtText += "- "
                                                        }
                                                        
                                                        // needed to prevent a nil which crash
                                                        if let lastChar = thoughtText.last {
                                                            lastValue = String(lastChar)
                                                        } else {
                                                            lastValue = ""
                                                        }
                                                    }
                                                    .onTapGesture {
                                                        if thoughtText == "" {
                                                            thoughtText = "- "
                                                        }
                                                    }
                                            }
                                        }
                                    }
                                }
                                // draw
                                if drawer { 
                                    VStack {
                                        HStack {
                                            VStack {
                                                Button {
                                                    lines = []
                                                    drawOpened = false
                                                } label: {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .stroke(.white, lineWidth: 2)
                                                            .frame(width: 30, height: 38)
                                                            .background(.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        
                                                        
                                                        Image(systemName: "archivebox")
                                                            .foregroundStyle(.white)
                                                            .shadow(color: .gray, radius: 5, x: 0, y: 0)
                                                    }
                                                }
                                                .padding()
                                                .scaleEffect( drawOpened ? 1.0 : 0 )
                                                .frame(maxWidth: drawOpened ? .infinity : 0)
                                                .fixedSize()
                                                
                                                Button {
                                                    if lines.count > 1 {
                                                        lines.removeLast()
                                                    } else {
                                                        lines = []
                                                        drawOpened = false 
                                                    }
                                                } label: {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .stroke(.white, lineWidth: 2)
                                                            .frame(width: 30, height: 38)
                                                            .background(.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        
                                                        
                                                        Image(systemName: "arrow.uturn.backward.circle")
                                                            .foregroundStyle(.white)
                                                            .shadow(color: .gray, radius: 5, x: 0, y: 0)
                                                    }
                                                }
                                                .scaleEffect( drawOpened ? 1.0 : 0 )
                                                .frame(maxWidth: drawOpened ? .infinity : 0)
                                                .fixedSize()
                                            }
                                            .padding()
                                            .frame(width: drawOpened ? 50 : 0)
                                            .fixedSize()
                                            
                                            ZStack {
                                                
                                                if currentLine.points.isEmpty && lines.isEmpty {
                                                    Text("Draw Ideas While Working!")
                                                        .foregroundColor(.gray)
                                                        .font(.title3)
                                                }
                                                
                                                Canvas { context, size in
                                                    for line in lines {
                                                        var path = Path()
                                                        path.addLines(line.points)
                                                        context.stroke(path, with: .color(line.color), lineWidth: chosenWidth)
                                                    }
                                                    
                                                    // Draw the current line
                                                    var currentPath = Path()
                                                    currentPath.addLines(currentLine.points)
                                                    context.stroke(currentPath, with: .color(currentLine.color), lineWidth: chosenWidth)
                                                }
                                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                                    .onChanged { value in
                                                        let newPoint = value.location
                                                        currentLine.points.append(newPoint)
                                                        drawOpened = true
                                                    }
                                                    .onEnded { value in
                                                        lines.append(currentLine)
                                                        currentLine = Line(points: [])
                                                    }
                                                )
                                                // .padding()
                                                .frame(width: drawOpened ? screenWidth/2.5 : screenWidth/2.2, height: screenHeight/3)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(.white, lineWidth: 3)
                                                    
                                                }
                                                
                                            }
                                        }
                                    }
                                    .padding()
                                }
                            }
                            .frame(width: screenWidth/2)
                            
                            
                        }
                        
                        
                    }
                    .frame(width: screenWidth/2)
                }
                
                
            }
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.3))
            
        }
        .onAppear {
            if thoughtText != "" {
                thoughtsOpened = true
            }
            
            if currentTab == "+erder" {
                currentTab = "Basic List"
            }
            
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
                
                
                var sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] < dueDates[$1] })
                
                // rearrange all arrays based on sorted indices
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
            
            
            if pomoOpened == false {
                progressTimePomo = pomoTime
                pomoOpened = true
            }
            
            progressTimePomo = progressTimePomo
            
            if opened == false {
                progressTime = 0
                opened = true
            }
            progressTime = progressTime
        
        }
        .onChange(of: selectedTab) {
            
            if thoughtText != "" {
                thoughtsOpened = true
            }
            
            if currentTab == "+erder" {
                currentTab = "Basic List"
            }
            
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
                
                
                var sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] < dueDates[$1] })
                
                // rearrange all arrays based on sorted indices
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
            
            
            if pomoOpened == false {
                progressTimePomo = pomoTime
                pomoOpened = true
            }
            
            progressTimePomo = progressTimePomo
            
            if opened == false {
                progressTime = 0
                opened = true
            }
            progressTime = progressTime
            
            
            
        }
        
        .onChange(of: currentTab) {
            Drops.hideAll()
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
                
                
                selectDelete = Array(repeating: false, count: infoArray.count)
                DateFormatter().dateFormat = "M/d/yyyy, h:mm a"
                
                
                if bigDic[currentTab]?["description"] != [] && bigDic[currentTab]?["description"] != [String()] {
                    
                    var sortedIndices = dueDates.indices.sorted(by: { dueDates[$0] < dueDates[$1] })
                    
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
                
            }
        }
        .onChange(of: breakText) {
            scheduleTimeBasedNotification(title: "\(breakText ? "Break" : "Pomo") Time!", body: "\(breakText ? "Pomo" : "Break") Completed!", sound: UNNotificationSound(named: UNNotificationSoundName(rawValue: alarmLevel)))
        }
        
    }
}

func resetDefaults() {
    let defaults = UserDefaults.standard
    let dictionary = defaults.dictionaryRepresentation()
    dictionary.keys.forEach { key in
        defaults.removeObject(forKey: key)
    }
}
extension UserDefaults {
    
    enum Keys: String, CaseIterable {
        
        case unitsNotation
        case temperatureNotation
        case allowDownloadsOverCellular
        
    }
    
    func reset() {
        Keys.allCases.forEach { removeObject(forKey: $0.rawValue) }
    }
    
}
func foregroundStyler(dueDate: Date, assignment: String) -> Color {
    
    if dueDate < Date().addingTimeInterval(86400) {
        if dueDate < Date().addingTimeInterval(3600) {
            return Color.red
        } else {
            return Color.orange
        }
    } else {
        return Color.green
        
    }
}

func styleNotification(dueDate: Date, assignment: String, description: String, alarm: String) {
    var number = 0
    
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
        if dueDate < Date().addingTimeInterval(86400) {
            if dueDate < Date().addingTimeInterval(3600) && number == 1 {
                scheduleTimeBasedNotification(title: "\(assignment) is due in less than one hour!", body: "\(description)", sound: UNNotificationSound(named: UNNotificationSoundName(rawValue: alarm)))
                number += 1
                if dueDate <= Date() && number == 2 {
                    scheduleTimeBasedNotification(title: "\(assignment) is due now!", body: "\(description)", sound: UNNotificationSound(named: UNNotificationSoundName(rawValue: alarm)))
                    number += 1
                }
                
            } else if number == 0 {
                scheduleTimeBasedNotification(title: "\(assignment) is due in less than one day!", body: "\(description)", sound: UNNotificationSound.defaultCritical)
                number += 1
            }
        }
    }
}

struct Line {
    var points: [CGPoint]
    var color: Color = .white
}

func dateFormatClean(str : Date) -> String {
    
    let now = Date()
    
    let calendar = Calendar.current
    
    let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: str)
    
    let formatter = DateComponentsFormatter()

    if components.day ?? 0 == 1 {
        
        formatter.allowedUnits = [.day, .hour]
        
    } else if components.day ?? 0 < 1 {
        
        formatter.allowedUnits = [.hour, .minute]
        
    } else {
        
        formatter.allowedUnits = [.day]
        
    }
    
    formatter.unitsStyle = .full
    
    return formatter.string(from: components) ?? ""
}
