import SwiftUI
import SafariServices

struct InstagramSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safariViewController = SFSafariViewController(url: url, configuration: config)
        safariViewController.preferredBarTintColor = UIColor.systemBackground
        safariViewController.preferredControlTintColor = UIColor.systemBlue
        safariViewController.dismissButtonStyle = .close
        
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

struct InstagramLinkButton: View {
    let username: String
    @State private var showingSafari = false
    
    var instagramUrl: URL {
        URL(string: "https://www.instagram.com/\(username)/")!
    }
    
    var body: some View {
        Button(action: {
            showingSafari = true
        }) {
            HStack {
                // Instagram icon
                Image(systemName: "camera")
                    .font(.title3)
                
                Text("View @\(username)")
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.5, green: 0.2, blue: 0.8),
                        Color(red: 0.8, green: 0.2, blue: 0.5),
                        Color(red: 1.0, green: 0.4, blue: 0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .sheet(isPresented: $showingSafari) {
            InstagramSafariView(url: instagramUrl)
                .edgesIgnoringSafeArea(.all)
                .presentationSizing(.page)
        }
    }
}
