import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Pow
import ChangelogKit

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
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                if !viewModel.isGuestUser {
                    AsyncImage(url: URL(string: viewModel.userImage ?? "")) { image in
                        image
                            .resizable()
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .frame(width: 100, height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(lineWidth: 5))
                    } placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15).stroke(.gray)
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
//                    Button {
//                        darkMode.toggle()
//                    } label: {
//                        HStack {
//                            Text("\(darkMode ? "Dark" : "Light") Mode")
//                            
//                            if darkMode {
//                                Image(systemName: "moon.fill")
//
//                            } else {
//                                Image(systemName: "sun.max.fill")
//
//                            }
//                        }
//                        .imageScale(.large)
//                        .padding(8)
//                    }
//                    .padding()
//                    .buttonStyle(.borderedProminent)
//                    .tint(darkMode ? .purple : .yellow)
                    CustomToggleSwitch(boolean: $darkMode, colors: [.purple, .yellow], images: ["moon.fill", "sun.max.fill"])

                    Button {
                        animationsPlus.toggle()
                    } label: {
                        HStack {
                            Text("\(animationsPlus ? "Lots of" : "Light") Animations")
                            
                            if animationsPlus {
                                Image(systemName: "star.fill")

                            } else {
                                Image(systemName: "star.slash.fill")

                            }
                        }
                        .imageScale(.large)
                        .padding(8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(animationsPlus ? .blue : .orange)
                    .fixedSize()
                    
                    Spacer()
                    
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
                        
                    }
                    .fixedSize()
                    
                    if !viewModel.isGuestUser {
                        FeatureReportButton(uid: viewModel.uid ?? "None")
                            .fixedSize()
                    }
                    
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
                            removeClubsListener()
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
                    features.append(Changelog.Feature(symbol: i.symbol ?? "", title: i.title, description: i.notes?.map { "* \($0)" }.joined(separator: "\n") ?? "", color: i.color ?? .blue))
                }
                
                recentVersionForChangelogLibrary = Changelog(version: changeLogViewModel.currentVersion.version, features: features)
                isNewChangeLogShown = true
            }
        }
        .sheet(isPresented: $isNewChangeLogShown, changelog: recentVersionForChangelogLibrary)
        .frame(maxHeight: screenHeight - screenHeight/6 - 36)
        .padding()
        .background(Color.systemGray6.cornerRadius(15).padding())
        .onAppear {
            if !viewModel.isGuestUser && debugTools {
                if let UserID = viewModel.uid {
                    fetchUser(for: UserID) { user in
                        userInfo = user
                        
                        if let favoriteClubs = userInfo?.favoritedClubs {
                            if !favoriteClubs.filter({ !$0.contains(" ") }).isEmpty {
                                getFavoritedClubNames(from: favoriteClubs) { clubNames in
                                    favoriteText = "Favorited Clubs: \(clubNames.joined(separator: ", "))"
                                }
                            } else {
                                favoriteText = "Favorited Clubs: None"
                                
                            }
                        }
                    }
                }
            }
        }
    }
}
