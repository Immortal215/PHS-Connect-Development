import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Pow
import ChangelogKit
import Combine
import Shimmer
import SDWebImageSwiftUI

struct SettingsView: View {
    var viewModel: AuthenticationViewModel
    @Binding var userInfo: Personal?
    @Binding var showSignInView: Bool
    @State var favoriteText = ""
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?
    @AppStorage("darkMode") var darkMode = false
    @AppStorage("debugTools") var debugTools = false
    @State var isChangelogShown = false
    @ObservedObject var changeLogViewModel = ChangelogViewModel()
    @AppStorage("mostRecentVersionSeen") var mostRecentVersionSeen = "0.1.0 Alpha"
    var screenHeight = UIScreen.main.bounds.height
    @State var isNewChangeLogShown = false
    @State var recentVersionForChangelogLibrary : Changelog = Changelog.init(version: "0.1.0 Alpha", features: [])
    @AppStorage("Animations+") var animationsPlus = false
    @State var darkModeBuffer = false
    @State var animationsPlusBuffer = false
    @State var debounceCancellable: AnyCancellable?
    @AppStorage("openToDo") var openToDo = false
    @State var autoBuffer = false
    @AppStorage("autoColorScheme") var autoColorScheme = true
    @Environment(\.colorScheme) var colorScheme
    @State var globalChatsEnabled = true
    @State var didLoadGlobalChatsSetting = false
    @State var globalChatsRef: DatabaseReference?
    @State var globalChatsHandle: DatabaseHandle?
    @State var isSavingGlobalChatsSetting = false

    var isSuperAdmin: Bool {
        isSuperAdminEmail(viewModel.userEmail ?? userInfo?.userEmail)
    }

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                if !viewModel.isGuestUser {
                    WebImage(url: URL(string: viewModel.userImage ?? "")) { image in
                        image
                            .resizable()
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .frame(width: 100, height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 25).stroke(lineWidth: 5))
                    } placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25).stroke(.gray)
                            ProgressView("Loading...")
                        }
                        .frame(width: 100, height: 100)
                    }
                    .padding(.trailing)
                    .onTapGesture(count: 5) {
                        debugTools.toggle()
                    }
                }
                
                VStack(alignment: .leading) {
                    Text(viewModel.userName ?? "No name")
                        .font(.largeTitle)
                        .bold()
                    
                    Text(viewModel.userEmail ?? "No Email")
                    
                    Text("\(viewModel.userType ?? "User Type Not Found")")
                }
                
                Spacer()
                
                if debugTools {
                    VStack(alignment: .trailing) {
                        Text("User UID (ONLY USE FOR TESTING) : \(viewModel.uid ?? "Not Found")")
                        
                        if !viewModel.isGuestUser {
                            Text(favoriteText)
                        }
                    }
                }
            }
            .padding()
            
            Divider()

            if isSuperAdmin {
                HStack(spacing: 12) {
                    Image(systemName: globalChatsEnabled ? "checkmark.bubble.fill" : "xmark.octagon.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(globalChatsEnabled ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Chats")
                            .font(.headline)
                        Text(globalChatsEnabled ? "Chats are enabled for everyone" : "Chats are blocked for everyone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { globalChatsEnabled },
                        set: { newValue in
                            globalChatsEnabled = newValue
                            setGlobalChatsEnabled(newValue)
                        }
                    ))
                    .labelsHidden()
                    .tint(globalChatsEnabled ? .green : .red)
                    .disabled(!didLoadGlobalChatsSetting || isSavingGlobalChatsSetting)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.systemGray6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(globalChatsEnabled ? Color.green.opacity(0.35) : Color.red.opacity(0.45), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            Button {
            } label: {
                HStack(spacing: 16) {
                    VStack {
                        CustomToggleSwitch(boolean: $autoBuffer, colors: [.gray, .green], images: ["lightbulb.slash", "sun.dust"])
                            .onChange(of: autoBuffer) { newValue in
                                debounceCancellable?.cancel()
                                
                                debounceCancellable = Just(newValue)
                                    .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
                                    .sink { finalValue in
                                        autoColorScheme = !finalValue
                                    }
                            }
                            .onChange(of: colorScheme) {
                                if autoColorScheme {
                                    darkMode = (colorScheme == .dark)
                                }
                            }
                        
                        CustomToggleSwitch(boolean: $darkModeBuffer, enabled: !autoColorScheme, colors: [autoColorScheme ? .gray : .purple, autoColorScheme ? .gray : .yellow], images: ["moon.fill", "sun.max.fill"])
                            .onChange(of: darkModeBuffer) { newValue in // need all this stuff to make sure that when dark mode is changing (with a lil lag) it does not impede the switching animation which would look like lag
                                debounceCancellable?.cancel()
                                
                                debounceCancellable = Just(newValue)
                                    .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
                                    .sink { finalValue in
                                        if !autoColorScheme {
                                            darkMode = finalValue
                                        }
                                    }
                            }
                    }
                    
                    CustomToggleSwitch(boolean: $animationsPlusBuffer, colors: [.blue, .orange], images: ["star.fill", "star.slash.fill"])
                        .onChange(of: animationsPlusBuffer) { newValue in // to make the animation smoother when toggling
                            animationsPlus = animationsPlusBuffer
                        }
                    Text("\(animationsPlus ? "Animations+ (BROKEN)" : "Basic Animations")")
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                animationsPlusBuffer.toggle()
                            }
                        }
                        .shimmering(active: animationsPlus, gradient: Gradient(colors: [.black.opacity(0.3), .black, .black.opacity(0.3)]))
                        .foregroundStyle(animationsPlus ? .blue : .orange)
                    
                    
                    Spacer()
                    
                    Button {
                        openToDo = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.blue, lineWidth: 3)
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .imageScale(.large)
                                    .rotationEffect(.degrees(10))
                                    .foregroundStyle(.teal)
                            }
                            .padding()
                        }
                        .fixedSize()
                        .foregroundColor(.blue)
                    }
                    
                    Button {
                        mostRecentVersionSeen = changeLogViewModel.currentVersion.version
                        isChangelogShown.toggle()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.blue, lineWidth: 3)
                                .fill(changeLogViewModel.currentVersion.version != mostRecentVersionSeen ? .blue : .clear)
                            HStack {
                                Image(systemName: "arrow.up.circle")
                                Text("Release Notes")
                            }
                            .padding()
                            .foregroundStyle(changeLogViewModel.currentVersion.version != mostRecentVersionSeen ? .white : .blue)
                        }
                        .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $isChangelogShown) {
                        ChangelogSheetView(
                            currentVersion: changeLogViewModel.currentVersion,
                            history: changeLogViewModel.history
                        )
                        .fontDesign(.monospaced)
                        .cornerRadius(25)

                    }
                    .fixedSize()
                    
                    FeatureReportButton(uid: viewModel.uid ?? "None")
                        .fixedSize()
                    
                    
                    Button {
                        do {
                            try AuthenticationManager.shared.signOut()
                            userEmail = nil
                            userName = nil
                            userImage = nil
                            userType = nil
                            uid = nil
                            userInfo = nil
                            showSignInView = true
                        } catch {
                            print("Error signing out: \(error.localizedDescription)")
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(lineWidth: 3)
                            HStack {
                                Image(systemName: "person")
                                Text("Logout")
                            }
                            .padding()
                        }
                        .foregroundColor(.red)
                    }
                    .fixedSize()
                    
                }
                .frame(height: 30)
            }
            .padding()
            
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Update \(changeLogViewModel.currentVersion.date)\nProspect High School - Immortal215")
                        .font(.caption2)
                    
                    Text("Version \(changeLogViewModel.currentVersion.version)")
                        .monospaced()
                        .font(.body)
                }
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear {
            startGlobalChatsListener()
            
            if mostRecentVersionSeen != changeLogViewModel.currentVersion.version {
                var features : [Changelog.Feature] = []
                for i in changeLogViewModel.currentVersion.changes {
                    features.append(Changelog.Feature(symbol: i.symbol ?? "", title: i.title, description: i.notes?.map { "- \($0)" }.joined(separator: "\n") ?? "", color: i.color ?? .blue))
                }
                
                recentVersionForChangelogLibrary = Changelog(version: changeLogViewModel.currentVersion.version, features: features)
                isNewChangeLogShown = true
            }
            darkModeBuffer = darkMode
            animationsPlusBuffer = animationsPlus
        }
        .onDisappear {
            stopGlobalChatsListener()
        }
        .sheet(isPresented: $isNewChangeLogShown, changelog: recentVersionForChangelogLibrary)
        .onChange(of: isNewChangeLogShown) { old, new in
            if old == true && new == false {  // onDismis dont work for some reason with this libary
                mostRecentVersionSeen = changeLogViewModel.currentVersion.version
            }
        }
        .frame(maxHeight: screenHeight - screenHeight/6 - 36)
        .padding()
        .background(Color.systemGray6.cornerRadius(15).padding())

    }
    
    func startGlobalChatsListener() {
        stopGlobalChatsListener()
        
        let ref = Database.database().reference()
            .child("global")
            .child("chatsEnabled")
        
        globalChatsRef = ref
        globalChatsHandle = ref.observe(.value) { snapshot in
            DispatchQueue.main.async {
                if let enabled = boolFromGlobalSetting(snapshot.value) {
                    globalChatsEnabled = enabled
                } else {
                    globalChatsEnabled = true
                }
                didLoadGlobalChatsSetting = true
            }
        }
    }
    
    func stopGlobalChatsListener() {
        if let ref = globalChatsRef, let handle = globalChatsHandle {
            ref.removeObserver(withHandle: handle)
        }
        globalChatsHandle = nil
        globalChatsRef = nil
    }
    
    func setGlobalChatsEnabled(_ enabled: Bool) {
        guard isSuperAdmin else { return }
        isSavingGlobalChatsSetting = true
        globalChatsRef?.setValue(enabled) { error, _ in
            DispatchQueue.main.async {
                isSavingGlobalChatsSetting = false
                if let error {
                    print("Failed to update /global/chatsEnabled: \(error.localizedDescription)")
                    globalChatsRef?.observeSingleEvent(of: .value) { snapshot in
                        globalChatsEnabled = boolFromGlobalSetting(snapshot.value) ?? true
                    }
                }
            }
        }
    }
    
    func boolFromGlobalSetting(_ rawValue: Any?) -> Bool? {
        if let boolValue = rawValue as? Bool {
            return boolValue
        }
        
        if let numberValue = rawValue as? NSNumber {
            return numberValue.boolValue
        }
        
        if let intValue = rawValue as? Int {
            return intValue != 0
        }
        
        if let stringValue = rawValue as? String {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "true" || normalized == "1" || normalized == "yes" {
                return true
            }
            if normalized == "false" || normalized == "0" || normalized == "no" {
                return false
            }
        }
        
        return nil
    }
}
