import AWSCognitoIdentityProvider
import Foundation
import SwiftUI

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
      .alert(
        "Password error", isPresented: $handler.isNewPassError, presenting: handler.newPassError,
        actions: { t in
          Button("Ok") {

          }
        },
        message: { err in
          Text(err.message)
        }
      )
      .environment(\.colorScheme, .dark)
    }
  }
}

struct NewPassPreviews: PicsPreviewProvider, PreviewProvider {
  static var preview: some View {
    NewPassView(handler: LoginHandler())
  }
}
