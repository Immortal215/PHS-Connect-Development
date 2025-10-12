import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Pow
import ChangelogKit
import Combine
import Shimmer

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
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                if !viewModel.isGuestUser {
                    AsyncImage(url: URL(string: viewModel.userImage ?? "")) { image in
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
            if mostRecentVersionSeen != changeLogViewModel.currentVersion.version {
                var features : [Changelog.Feature] = []
                for i in changeLogViewModel.currentVersion.changes {
                    features.append(Changelog.Feature(symbol: i.symbol ?? "", title: i.title, description: i.notes?.map { "- \($0)" }.joined(separator: "\n") ?? "", color: i.color ?? .blue))
                }
                
                recentVersionForChangelogLibrary = Changelog(version: changeLogViewModel.currentVersion.version, features: features)
                isNewChangeLogShown = true
            }
            darkModeBuffer = darkMode
            autoBuffer = !autoColorScheme
            animationsPlusBuffer = animationsPlus
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
}
