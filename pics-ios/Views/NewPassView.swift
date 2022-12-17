import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

struct NewPassView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var handler: LoginHandler

    @State var password: String = ""
    
    var body: some View {
        ZStack {
            if handler.isNewPassComplete {
                ProgressView().onAppear {
                    dismiss()
                }
            }
            color.background
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Text("Enter a new password.")
                    .foregroundColor(color.almostLight)
                BoatPasswordField("Password", password: $password)
                Button {
                    guard password != "" else { return }
                    handler.save(password: password)
                } label: {
                    ButtonText("Save")
                }
                Spacer()
            }
            .frame(maxWidth: 400)
            .alert("Password error", isPresented: $handler.isNewPassError, presenting: handler.newPassError, actions: { t in
                Button("Ok") {
                    
                }
            }, message: { err in
                Text(err.message)
            })
            .environment(\.colorScheme, .dark)
        }
    }
}

struct NewPass_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            NewPassView(handler: LoginHandler())
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
