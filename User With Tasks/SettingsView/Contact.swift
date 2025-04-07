import SwiftUI
import MessageUI

struct FeatureReportButton: View {
    @State var isShowingMailView = false
    @State var alertMessage = ""
    @State var showAlert = false
    var uid: String
    @ObservedObject var changeLogViewModel = ChangelogViewModel()
    
    let recipientEmail = "sharulshah@icloud.com"
    let subject = "Feature Report"
    
    var body: some View {
        Button(action: {
            if MFMailComposeViewController.canSendMail() {
                isShowingMailView = true
            } else {
                openGmailApp()
            }
        }) {
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 20))
                Text("Submit Feature Report")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $isShowingMailView) {
            MailView(
                isShowing: $isShowingMailView,
                result: { result in
                    switch result {
                    case .success:
                        alertMessage = "Thank you for your feature report!"
                    case .failure:
                        alertMessage = "Failed to send email"
                    }
                    showAlert = true
                },
                content: MailContent(
                    subject: subject,
                    recipients: [recipientEmail],
                    message: createEmailTemplate()
                )
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Feature Report"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    func createEmailTemplate() -> String {
        """
        Device Information:
        • Model: \(UIDevice.current.model)
        • iOS Version: \(UIDevice.current.systemVersion)
        • Device Width: \(UIScreen.main.bounds.width)
        • Device Height: \(UIScreen.main.bounds.height)
        • User UID : \(uid)
        • App Version : \(changeLogViewModel.currentVersion.version)
        
        Feature/ Bug Request Details:
        Please describe the issue or feature you'd like to recognize:
        
        
        How would you fix/ change this?: 
        
        
        Additional comments/ resources to help:
        
        """
    }
    
    func openGmailApp() {
        let encodedBody = createEmailTemplate().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let gmailURLString = "googlegmail://co?to=\(recipientEmail)&subject=\(subject)&body=\(encodedBody)"
        let mailtoURLString = "mailto:\(recipientEmail)?subject=\(subject)&body=\(encodedBody)"
        
        if let gmailURL = URL(string: gmailURLString), UIApplication.shared.canOpenURL(gmailURL) {
            UIApplication.shared.open(gmailURL)
        } else if let mailtoURL = URL(string: mailtoURLString) {
            UIApplication.shared.open(mailtoURL)
        } else {
            alertMessage = "No email app available. Please set up an email account."
            showAlert = true
        }
    }
}

struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    let result: (Result<MFMailComposeResult, Error>) -> Void
    let content: MailContent
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setSubject(content.subject)
        mailComposer.setToRecipients(content.recipients)
        mailComposer.setMessageBody(content.message, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.result(.failure(error))
            } else {
                parent.result(.success(result))
            }
            parent.isShowing = false
        }
    }
}

struct MailContent {
    let subject: String
    let recipients: [String]
    let message: String
}
