import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX


struct AddAnnouncementSheet: View {
    @State var announcementBody: String
    @State var clubID: String
    @Environment(\.presentationMode) var presentationMode
    var onSubmit: () -> Void

    var body: some View {
            VStack {
                Text("Add Announcement")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                TextField("Enter announcement details...", text: $announcementBody)
                    .padding()
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 150)
                    .padding(.horizontal)

                Spacer()

                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundStyle(.gray)
                    .padding()
                    .background(Capsule().strokeBorder(Color.gray, lineWidth: 1))

                    Spacer()

                    Button("Post (Cannot Re-Edit)") {
                        if !announcementBody.isEmpty {
                            addAnnouncment(clubID: clubID, date: formattedDate(from: Date()), body: announcementBody)
                            onSubmit()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Capsule().fill(Color.blue))
                }
                .padding(.horizontal)
            }
            .padding()
        
    }
}
