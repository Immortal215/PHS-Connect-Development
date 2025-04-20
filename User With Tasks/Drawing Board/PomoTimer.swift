import SwiftUI
import UserNotifications
import Pow
import Drops

struct Pomo: View {
    @State var screenWidth = UIScreen.main.bounds.width
    @State var screenHeight = UIScreen.main.bounds.height
    @AppStorage("pomotimer") var pomoTime = 1500
    @AppStorage("breakTime") var breakTime = 300
    @AppStorage("breaks") var breaks = 4
    @AppStorage("pomoOpened") var pomoOpened = false
    @AppStorage("opened") var opened = false
    @AppStorage("currentBreaks") var currentBreaks = 0
    @AppStorage("breakText") var breakText = false
    @AppStorage("cornerRadius") var cornerRadius = 300
    
    var timer: Timer {
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {_ in
            
            progressTime += 1
            
        }
    }
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
    @State var myTimer:Timer?
    
    @AppStorage("timered") var timered = false
    @AppStorage("timeredStart") var timeredStart = false
    
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
    @State var pomoClicked = false
    @State var textPomo = ""
    @State var endString = ""
    
    var body: some View {
        ZStack {
            NavigationStack {
                
                HStack {
                    
                    Spacer()
                    VStack {
                        Text("StopWatch")
                            .font(.title)
                            .fontWeight(.semibold)
                        Spacer()
                        if progressTime != 0 {
                            Button("Reset") {
                                progressTime = 0
                                myTimer?.invalidate()
                            } 
                            .foregroundStyle(.blue)
                        }
                        
                        Text("\(hours != "00" ? "\(hours):" : "")\(minutes):\(seconds)")
                            .font(.system(size: 100))
                        
                        VStack {
                            HStack {
                                Button {
                                    timer.invalidate()
                                    myTimer?.invalidate()
                                    myTimer = timer
                                    
                                } label: {
                                    RoundedRectangle(cornerRadius: 20)
                                        .foregroundStyle(.green)
                                        .opacity(0.6)
                                        .overlay(
                                            Text("Start")
                                                .font(.custom("", fixedSize: 50))
                                                .foregroundStyle(.white)
                                                .animation(.bouncy(duration: 1, extraBounce: 0.1))
                                            
                                        )
                                        .frame(width:200, height:100)
                                    
                                }
                                
                                
                                
                                Button {
                                    myTimer?.invalidate()
                                } label: {
                                    RoundedRectangle(cornerRadius: 20)
                                        .foregroundStyle(.red)
                                        .opacity(0.6)
                                        .overlay(
                                            Text("Stop")
                                                .font(.custom("", fixedSize: 50))
                                                .foregroundStyle(.white)
                                        )
                                        .frame(width:200, height:100)
                                }
                            }
                            
                        }
                        Spacer()
                    }
                    .frame(width: screenWidth/2)
                    Spacer()
                    
                    Spacer()
                    VStack {
                        Text("Pomodoro Timer")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Spacer(minLength: 50)
                        
                        Button {
                            timerPomo.invalidate()
                            myTimerPomo?.invalidate()
                            // cornerRadius = Int.random(in: 1...300)
                            pomoClicked = true
                            textPomo = String(pomoTime/60)
                            
                        }  label : {
                            
                            ZStack {
                                
                                RoundedRectangle(cornerRadius: CGFloat(cornerRadius))
                                    .stroke(lineWidth: 25)
                                    .opacity(0.3)
                                    .foregroundColor(.gray)
                                    .animation(.linear(duration: 1))
                                
                                RoundedRectangle(cornerRadius: CGFloat(cornerRadius))
                                    .trim(from: 0.0, to: CGFloat(breakText ? Double(progressTimePomo)/Double(breakTime) : Double(progressTimePomo)/Double(pomoTime)))
                                    .stroke(style: StrokeStyle(lineWidth: 25, lineCap: .round, lineJoin: .round))
                                    .rotationEffect(Angle(degrees: -90.0))
                                    .animation(.linear(duration: 1))
                                    .foregroundStyle(breakText ? .green : .pink)
                                    .opacity(0.3)
                                
                                VStack {
                                    
                                    Text("Timer will conclude at \(endString)")
                                    
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                        .offset(y:-85)
                                    
                                    Text("\(minutesPomo):\(secondsPomo)")
                                        .font(.system(size: 100))
                                        .foregroundStyle(breakText ? .green : .pink)
                                        .opacity(0.5)
                                        .padding(-100)
                                    Divider()
                                        .frame(width: 200)
                                    Text(pomoResulter(pomoTime: pomoTime, breakTime: breakTime, breakText: breakText))
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                    Text(currentBreaks > 0 ? "Breaks taken : \(currentBreaks)" : "")
                                        .font(.system(size:15))
                                        .foregroundStyle(.white)
                                }
                                .offset(y: 50)
                            }
                            .frame(width:screenWidth/3.5, height: screenWidth/3.5)
                            
                        }
                        .alert("Change Pomo Time!", isPresented: $pomoClicked) {
                            TextField("Custom (Minutes)", text: $textPomo)
                            
                        }
                        .onChange(of: textPomo) {
                            if Int(textPomo) ?? 0 != 0 && Int(textPomo) != nil && Int(textPomo) ?? 0 <= 60 {
                                pomoTime = (Int(textPomo) ?? 0) * 60
                                progressTimePomo = pomoTime
                                
                            } else if Int(textPomo) ?? 0 > 60 {
                                textPomo = "60"
                            }
                        }
                        
                        Spacer()
                        VStack {
                            
                            HStack {
                                Button {
                                    if timeredStart != true {
                                        timeredStart = true
                                        startTimer()
                                    }
                                } label: {
                                    Circle()
                                        .stroke(.green, lineWidth: 5)
                                        .opacity(0.6)
                                    
                                        .overlay(
                                            Text("Start")
                                                .font(.custom("",    fixedSize: 25))
                                                .foregroundStyle(.white)
                                                .animation(.bouncy(duration: 1, extraBounce: 0.1))
                                        )
                                        .frame(width:100, height:100)
                                    
                                }
                                .padding()
                                Button {
                                    timered = true
                                    stopTimer()
                                    Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { timer in
                                        progressTimePomo = pomoTime
                                        breaks = 0
                                        breakText = false
                                        currentBreaks = 0
                                        cornerRadius = 300
                                    }
                                } label: {
                                    RoundedRectangle(cornerRadius: 45)
                                        .stroke(.blue, lineWidth: 5)
                                        .opacity(0.6)
                                        .overlay(
                                            Text("Reset")
                                                .font(.custom("", fixedSize: 50))
                                                .foregroundStyle(.white)
                                        )
                                        .frame(width:200, height:100)
                                        .scaleEffect(progressTimePomo != pomoTime ? 1.0 : 0)
                                        .offset(y: progressTimePomo != pomoTime ? 0 : -10)
                                }
                                .animation(.spring(duration: 1, bounce: 0.3, blendDuration: 0.3))
                                .padding()
                                
                                Button {
                                    timered = true
                                    stopTimer()
                                    
                                } label: {
                                    Circle()
                                        .stroke(.red, lineWidth: 5)
                                        .opacity(0.6)
                                    
                                        .overlay(
                                            Text("Stop")
                                                .font(.custom("", fixedSize: 25))
                                                .foregroundStyle(.white)
                                        )
                                        .frame(width:100, height:100)
                                }
                                .padding()
                            }
                            .padding()
                            
                            
                            
                            
                            Spacer()
                        }
                    }
                    .frame(width: screenWidth/2)
                }
                .animation(.snappy(duration: 0.3, extraBounce: 0.3))
            }
            
        }
        .onAppear {
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
            
            endString = myTimerPomo?.isValid ?? false ? Date(timeIntervalSinceNow: Double(progressTimePomo)).formatted(date: .omitted, time: .shortened) : "??:??"
            
        }
        
        .onChange(of: pomoTime) {
            myTimerPomo?.invalidate()
            progressTimePomo = pomoTime
            endString = myTimerPomo?.isValid ?? false ? Date(timeIntervalSinceNow: Double(progressTimePomo)).formatted(date: .omitted, time: .shortened) : "??:??"
        }
        .onChange(of: breakTime) {
            myTimerPomo?.invalidate()
        }
        .onChange(of: myTimerPomo) {
            endString = myTimerPomo?.isValid ?? false ? Date(timeIntervalSinceNow: Double(progressTimePomo)).formatted(date: .omitted, time: .shortened) : "??:??"
        }
        
        // test without
        //        .onChange(of: breakText) {
        //            scheduleTimeBasedNotification(title: "\(breakText ? "Break" : "Pomo") Time!", body: "\(breakText ? "Pomo" : "Break") Completed!", sound: UNNotificationSound(named: UNNotificationSoundName(rawValue: "myalarm.mp3")))
        //        }
        
        
    }
}

func scheduleTimeBasedNotification(title: String, body: String, sound: UNNotificationSound) {
    
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("Permission granted")
            
            let drop = Drop(
                title: title,
                subtitle: body,
                icon: UIImage(systemName: "star.fill"),
                action: .init {
                    print("Drop tapped")
                    Drops.hideCurrent()
                },
                position: .top,
                duration: 10.0,
                accessibility: "Alert: Title, Subtitle"
            )
            Drops.show(drop)
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = sound
            // UNNotificationSound(named: UNNotificationSoundName(rawValue: "myalarm.mp3"))
            //  UNNotificationSound.defaultCritical
            
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding notification: \(error.localizedDescription)")
                } else {
                    print("Notification scheduled")
                }
            }
        } else if let error = error {
            print("Authorization error: \(error.localizedDescription)")
        } else {
            print("Permission not granted")
        }
    }
}

func pomoResulter(pomoTime : Int, breakTime : Int, breakText : Bool) -> String {
    
    return "\(breakText ? "Pomo" : "Break") Time : \(breakText ? (pomoTime >= 60 ? "\(pomoTime/60) Minutes (\(pomoTime)s)" : "\(pomoTime) Seconds") : (breakTime >= 60 ? "\(breakTime/60) Minutes (\(breakTime)s)" : "\(breakTime) Seconds"))"
}

struct ChunkyButton: ButtonStyle {
    @State var color : Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .padding()
            .background {
                ZStack {
                    Capsule()
                        .fill(color)
                        .stroke(.black, lineWidth: 3)
                        .offset(y: configuration.isPressed ? 0 : 10)
                        .opacity(0.5)
                        .saturation(0.6)
                    
                    Capsule()
                        .fill(color)
                        .stroke(.black, lineWidth: 3)
                        .saturation(0.6)
                }
            }
            .offset(y: configuration.isPressed ? 10: 0)
    }
}
