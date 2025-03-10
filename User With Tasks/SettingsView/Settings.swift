import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Pow

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
                HStack {
                    Button {
                        darkMode.toggle()
                    } label: {
                        HStack {
                            Text("\(darkMode ? "Dark" : "Light") Mode")
                            
                            if darkMode {
                                Image(systemName: "moon.fill")

                            } else {
                                Image(systemName: "sun.max.fill")

                            }
                        }
                        .imageScale(.large)
                        .padding(8)
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
                    .tint(darkMode ? .purple : .yellow)
                    
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
                    .padding()
                    .fixedSize()
                    .sheet(isPresented: $isChangelogShown) {
                        ChangelogSheetView(
                            currentVersion: changeLogViewModel.currentVersion,
                            history: changeLogViewModel.history
                        )
                        .fontDesign(.monospaced)
                        
                    }
                    
                    if !viewModel.isGuestUser {
                        FeatureReportButton(uid: viewModel.uid ?? "None")
                            .padding()
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
                    .padding()
                    .fixedSize()
                    
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Version \(changeLogViewModel.currentVersion.version)")
                        .monospaced()
                        .font(.body)
                    Text("\(changeLogViewModel.currentVersion.date)\nProspect High School - Immortal215")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        }
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
