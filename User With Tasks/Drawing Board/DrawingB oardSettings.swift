import SwiftUI
import Pow

struct Settinger: View {
    
    @State var screenWidth = UIScreen.main.bounds.width
    @State var screenHeight = UIScreen.main.bounds.height
    
    @AppStorage("duedatesetter") var dueDateSetter = "One Day"
    @State var dueDaters : [String] = ["Today", "One Hour", "6 Hours", "One Day", "Two Days", "Four Days", "Five Days"]
    @AppStorage("dueDater") var dueDater = "07:00"
    @State var datedVar = Date()
    @AppStorage("organizedAssignments") var organizedAssignments = "Due By Descending (Recent to Oldest)"
    @State var organizationOptions : [String] = ["Created By Descending (Recent to Oldest)", "Created By Ascending (Oldest to Recent)", "Due By Descending (Recent to Oldest)", "Due By Ascending (Oldest to Recent)"]
    
    @AppStorage("pomotimer") var pomoTime = 1500
    @State var textPomo = ""
    @State var timerOptions : [String] = ["Custom", "900", "1200", "1500", "1800"]
    
    @AppStorage("breakTime") var breakTime = 300
    @State var textBreak = ""
    @State var timerOptionsBreak : [String] = ["Custom", "180", "240", "300", "360"]
    
    @AppStorage("pomoOpened") var pomoOpened = false
    @AppStorage("opened") var opened = false
    
    
    @AppStorage("subjectcolor") var subjectColor : String = "#91E2FD"
    @State var hexSubjectColor : Color = Color(hexadecimal: "#91E2FD")
    
    @AppStorage("titlecolor") var titleColor : String = "#E2FFC2"
    @State var hexTitleColor : Color = Color(hexadecimal: "#E2FFC2")
    
    @AppStorage("descolor") var descriptionColor : String = "#FFFFFF"
    @State var hexDescriptionColor : Color = Color.white
    
    @AppStorage("chosenWidth") var chosenWidth = 5.0
    @AppStorage("chosenOpacity") var chosenOpacity = 0.8
    
    @AppStorage("urgentCount") var urgentCount = 3
    @State var clear = false 
    @State var clearCheck = false 
    @AppStorage("drawer") var drawer = true 
    @AppStorage("writer") var writer = true  
    
    @AppStorage("alarmLevel") var alarmLevel = "myalarm.mp3"
    @AppStorage("tabStyle") var tabStyle = true
    @AppStorage("pagedStyle") var pagedStyle = true
    @AppStorage("cornerRadius") var cornerRadius = 300
    
    @AppStorage("emptyClear") var emptyClear = false
    @AppStorage("subjectPicker") var subjectPicker = true
    
    @State var formatter = DateFormatter()
    @AppStorage("openToDo") var openToDo = false

    var body: some View {
        ZStack {
            VStack {
                Text("Settings")
                    .fontWeight(.semibold)
                    .font(.title)
                
                
                Form {
                    //planner
                    Section("Planner") {
                        LabeledContent {
                            HStack {
                                Picker("", selection: $dueDateSetter) {
                                    ForEach(dueDaters, id: \.self) { i in
                                        Text(i).tag(i)
                                    }
                                }
                                
                                DatePicker("", selection: $datedVar, displayedComponents: [.hourAndMinute])
                                    .onChange(of: datedVar) {
                                        dueDater = datedVar.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "")
                                        print(dueDater)
                                    }
                                    .datePickerStyle(.compact)
                            }
                            .fixedSize()
                        } label: {
                            Text("Due Date Chooser")
                            Text("Every new objective will start in **\(dueDateSetter)** at **\(datedVar.formatted(date: .omitted, time: .shortened))**")
                        }
                        
                        HStack {
                            Text("Assignment Organization Order")
                            
                            
                            Picker("", selection: $organizedAssignments) {
                                ForEach(organizationOptions, id: \.self) { i in
                                    Text(i).tag(i)
                                }
                            }
                        }
                        Toggle(isOn: $emptyClear) {
                            Text("Description Clear Button")
                            Text("A button to clear all spaces in your description")
                        }
                        
                        Toggle(isOn: $subjectPicker) {
                            Text("Subject Picker")
                            Text("A picker that allows you to choose from all subjects")
                        }
                        
                        DisclosureGroup("Planner Color Modifications") {
                            HStack {
                                
                                ColorPicker(selection: $hexSubjectColor) {
                                    Text("Subject")
                                    Button("Reset") {
                                        hexSubjectColor = Color(hexadecimal: "#91E2FD")
                                    }
                                }
                                
                                
                                
                            }
                            HStack {
                                
                                ColorPicker(selection: $hexTitleColor) {
                                    Text("Title")
                                    Button("Reset") {
                                        hexTitleColor = Color(hexadecimal: "#E2FFC2")
                                    }
                                }
                                
                                
                                
                                
                            }
                            HStack {
                                
                                ColorPicker(selection: $hexDescriptionColor) {
                                    Text("Description")
                                    Button("Reset") {
                                        hexDescriptionColor = Color(hexadecimal: "#FFFFFF")
                                    }
                                }
                                
                            }
                        }
                        
                    }
                    
                    // pomo timer
                    Section("Pomo Timer") {
                        //pomodoro time
                        HStack {
                            Text("Pomodoro Time")
                            
                            Picker("",selection: $pomoTime) {
                                if timerOptions.contains(String(pomoTime)) {
                                    ForEach(timerOptions, id: \.self) { i in
                                        if i != "Custom" {
                                            if i != "1500" {
                                                Text("\((Int(i)! / 60)) Minutes").tag((Int(i) ?? (pomoTime / 60) * 60))
                                            } else {
                                                Text("25 Minutes (Default)").tag((Int(i) ?? (pomoTime / 60) * 60))
                                            }
                                        }
                                    }
                                    
                                } else {
                                    Section("Custom") {
                                        if pomoTime >= 60 {
                                            Text("Custom \(pomoTime / 60) Minutes").tag(pomoTime)
                                        } else {
                                            Text("Custom \(pomoTime) Seconds").tag(pomoTime)
                                        }
                                    }
                                    Text("15 Minutes").tag(900)
                                    Text("20 Minutes").tag(1200)
                                    Text("25 Minutes (Default)").tag(1500)
                                    Text("30 Minutes").tag(1800)
                                    
                                    
                                }
                                
                            }
                            
                            TextField("Custom (Seconds)", text: $textPomo)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: textPomo) {
                                    if Int(textPomo) ?? 0 != 0 && Int(textPomo) != nil && Int(textPomo) ?? 0 <= 3600 {
                                        pomoTime = (Int(textPomo) ?? 0 * 60)
                                    } else if Int(textPomo) ?? 0 > 60 {
                                        textPomo = "3600"
                                    }
                                }
                                .frame(width: screenWidth/5)
                        }
                        
                        // break time
                        HStack {
                            Text("Break Time")
                            
                            Picker("",selection: $breakTime) {
                                if timerOptionsBreak.contains(String(breakTime)) {
                                    ForEach(timerOptionsBreak, id: \.self) { i in
                                        if i != "Custom" {
                                            if i != "300" {
                                                Text("\((Int(i)! / 60)) Minutes").tag((Int(i) ?? (breakTime / 60) * 60))
                                            } else {
                                                Text("5 Minutes (Default)").tag((Int(i) ?? (breakTime / 60) * 60))
                                            }
                                        }
                                    }
                                    
                                } else {
                                    Section("Custom") {
                                        if breakTime >= 60 {
                                            Text("Custom \(breakTime / 60) Minutes").tag(breakTime / 60)
                                        } else {
                                            Text("Custom \(breakTime) Seconds").tag(breakTime / 60)
                                        }
                                    }
                                    Text("3 Minutes").tag(180)
                                    Text("4 Minutes").tag(240)
                                    Text("5 Minutes (Default)").tag(300)
                                    Text("6 Minutes").tag(360)
                                    
                                    
                                }
                                
                            }
                            
                            TextField("Custom (Seconds)", text: $textBreak)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: textBreak) {
                                    
                                    if Int(textBreak) ?? 0 != 0 && Int(textBreak) != nil && Int(textBreak) ?? 0 <= 3600 {
                                        breakTime = (Int(textBreak) ?? 0 * 60)
                                    } else if Int(textBreak) ?? 0 > 60 {
                                        textBreak = "3600"
                                    }
                                }
                                .frame(width: screenWidth/5)
                        }
                        LabeledContent {
                            Stepper("",value: $cornerRadius, in: 1...300, step: 10)
                                .padding()
                            Button {
                                cornerRadius = Int.random(in: 1...300)
                            }  label : {
                                
                                ZStack {
                                    
                                    RoundedRectangle(cornerRadius: CGFloat(cornerRadius/3))
                                        .stroke(lineWidth: 10)
                                        .opacity(0.3)
                                        .foregroundColor(.gray)
                                        .animation(.linear(duration: 1))
                                    
                                    RoundedRectangle(cornerRadius: CGFloat(cornerRadius/3))
                                        .trim(from: 0.0, to: 0.8)
                                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                                        .rotationEffect(Angle(degrees: -90.0))
                                        .animation(.linear(duration: 1))
                                        .opacity(0.3)
                                    
                                    Text("Tap Me!\n\(cornerRadius)")
                                        .foregroundStyle(.blue)
                                        .multilineTextAlignment(.center)
                                    
                                }
                                .frame(width:100, height: 100)
                                
                            }
                            
                        } label : {
                            Text("Circle Shape Radius")
                        }
                    }
                    
                    // homepage
                    Section("Home") {
                        HStack {
                            Picker("Urgent Assignments Count" , selection: $urgentCount) {
                                Text("2").tag(2)
                                Text("3 (Default)").tag(3)
                                Text("4").tag(4)
                                Text("5").tag(5)
                                Text("All").tag(0)
                            }
                        }
                        Toggle("Thoughts Text", isOn: $writer)
                        LabeledContent {
                            HStack {
                                if drawer {      
                                    HStack {
                                        Text("1")
                                        Slider(value: $chosenWidth, in: 1...15, step: 0.5)
                                        Text("15")
                                    }
                                    .padding(.leading)
                                }
                                Toggle("", isOn: $drawer)
                            }
                            
                            
                        } label: {
                            Text("Drawing Pad")
                            if drawer {
                                Text("Draw Line Width: \(chosenWidth, specifier: "%.1f")")
                                Button("Reset") {
                                    chosenWidth = 5
                                }
                            }
                        }
                        
                        
                        Picker("Alarm Volume" , selection: $alarmLevel) {
                            Text("Base Alarm Level (Low, Wearing Headphones)").tag("myalarm.mp3")
                            Text("Alarm Level (Medium, Working W/O Headphones)").tag("myalarmMedium.mp3")
                            Section("Dangerous") {
                                Text("Alarm Level (High, Home Alone)").tag("myalarmHigh.mp3")
                            }
                            
                        }
                        
                    }
                    Section("Misc.") {
                        
                        LabeledContent {
                            HStack {
                                if tabStyle {      
                                    HStack {
                                        Text("0%")
                                        Slider(value: $chosenOpacity, in: 0.0...1.0, step: 0.01)
                                        Text("100%")
                                    }
                                    .padding(.leading)
                                }
                                Toggle("", isOn: $tabStyle) 
                                    .onTapGesture {
                                        if tabStyle == true {
                                            tabStyle = false 
                                            pagedStyle = true
                                        } else {
                                            tabStyle = true 
                                            pagedStyle = false 
                                        }
                                    }
                            }
                        } label: {
                            Text("Tab Bar")
                            if tabStyle {
                                Text("Tab Bar Opacity: \(Int(chosenOpacity * 100))%")
                                Button("Reset") {
                                    chosenOpacity = 0.8
                                }
                            }
                        }
                        
                        if tabStyle == false {
                            Toggle("Paged Tabs", isOn: $pagedStyle)
                        }
                        Button("CLEAR ALL DATA") {
                            clear.toggle()  
                            clearCheck = false 
                        } 
                        .font(.callout)
                        .foregroundStyle(.red)
                        .sheet(isPresented: $clear) {
                            Text("Are you sure???")
                            Button("Cancel") {
                                clear = false 
                                
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.green, lineWidth: 2)
                                    .frame(width: 75, height: 35)
                                
                            }
                            .padding()
                            .foregroundStyle(.green)
                            ZStack { 
                                Button(clearCheck ? "NO GOING BACK NOW" : "DELETE") {
                                    clearCheck.toggle()
                                    if clearCheck == false {
                                        resetDefaults()
                                        UserDefaults.standard.reset()
                                        clear = false 
                                    }
                                }
                                .foregroundStyle(.red)
                                .padding()
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.red, lineWidth: 2)
                                //   .frame(width: 75, height: 35)
                                
                            }
                            // .padding(0)
                            .fixedSize()
                            
                            //                            if clearCheck {
                            //                                Text("This is all your data :\n\(bigDic)")
                            //                            }
                        }
                    }
                    
                    Button {
                        openToDo = false
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.blue, lineWidth: 3)
                            HStack {
                                Text("Back to PHS Connect")
                            }
                            .padding()
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                    
                }
                .frame(width: screenWidth/1.3)
                
                
                Spacer()
                    .frame(height: 100)
            }
        }
        .onAppear {
            formatter.dateFormat = "HH:mm"
            if let time = formatter.date(from: dueDater) {
                let calendar = Calendar.current
                let currentDate = Date()
                let currentComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                
                var newComponents = currentComponents
                newComponents.hour = timeComponents.hour
                newComponents.minute = timeComponents.minute
                
                datedVar = calendar.date(from: newComponents) ?? Date()
            }
            
            hexSubjectColor = Color(hexadecimal: subjectColor)
            hexTitleColor = Color(hexadecimal: titleColor)
            hexDescriptionColor = Color(hexadecimal: descriptionColor)
            
        }
        .onChange(of: hexTitleColor) {
            titleColor = hexTitleColor.toHexString()
        }
        .onChange(of: hexDescriptionColor) {
            descriptionColor = hexDescriptionColor.toHexString()
        }
        .onChange(of: hexSubjectColor) {
            subjectColor = hexSubjectColor.toHexString()
        }
        .onChange(of: pomoTime) {
            textPomo = String(pomoTime)
        }
        .onChange(of: breakTime) {
            textBreak = String(breakTime)
        }
    }
}
