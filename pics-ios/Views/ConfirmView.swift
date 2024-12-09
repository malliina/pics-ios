import AWSCognitoIdentityProvider
import Foundation
import SwiftUI

extension AWSCognitoIdentityUser {
  func confirmSignUpAsync(username: String, code: String) async throws
    -> AWSCognitoIdentityUserConfirmSignUpResponse
  {
    return try await withCheckedThrowingContinuation { cont in
      confirmSignUp(code, forceAliasCreation: true).continueWith { task in
        if let error = SignupError.check(user: username, error: task.error) {
          cont.resume(throwing: error)
        } else if let result = task.result {
          cont.resume(returning: result)
        } else {
          cont.resume(throwing: SignupError.unknown)
        }
        return nil
      }
    }
  }
}

class ConfirmHandler: ObservableObject {
  let log = LoggerFactory.shared.vc(ConfirmHandler.self)
  var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }

  @Published var confirmError: SignupError? = nil
  @Published var isConfirmError: Bool = false
  @Published var feedback: String? = nil
  @Published var isFeedback: Bool = false

  private let loginHandler: LoginHandler
  var creds: PasswordCredentials? { loginHandler.creds }
  var username: String { creds?.username ?? "" }

  init(loginHandler: LoginHandler) {
    self.loginHandler = loginHandler
  }

  func submit(code: String) {
    Task {
      do {
        let _ = try await pool.getUser(username).confirmSignUpAsync(username: username, code: code)
        if let creds = self.creds {
          self.loginHandler.submit(credentials: creds)
        } else {
          self.log.info("Code confirmed, but no creds available.")
        }
      } catch let error {
        let signupError = error as? SignupError ?? SignupError.unknown
        DispatchQueue.main.async {
          self.confirmError = signupError
          self.isConfirmError = true
        }
      }
    }
  }

  func resendCode() {
    log.info("Resending code for user \(username)...")
    pool.getUser(username).resendConfirmationCode().continueWith { (task) -> Any? in
      DispatchQueue.main.async {
        if let error = SignupError.check(user: self.username, error: task.error) {
          self.confirmError = error
        } else {
          self.feedback = "A new confirmation code was sent."
          self.isFeedback = true
        }
      }
      return nil
    }
  }
}

struct ConfirmView: View {
  @ObservedObject var handler: ConfirmHandler

  @State var code: String = ""

  var body: some View {
    ZStack {
      color.background
        .edgesIgnoringSafeArea(.all)
      VStack {
        Text("Enter the code sent to the provided email address.")
        BoatTextField("Username", text: .constant(handler.username))
          .disabled(true)
        BoatTextField("Code", text: $code)
        Button {
          guard code != "" else { return }
          handler.submit(code: code)
        } label: {
          ButtonText("Confirm")
        }
        Button {
          handler.resendCode()
        } label: {
          Text("Resend code").foregroundColor(color.blueish2)
        }
      }
      .frame(maxWidth: 400)
      .environment(\.colorScheme, .dark)
    }.alert(
      "Code error", isPresented: $handler.isConfirmError, presenting: handler.confirmError,
      actions: { t in
        Button("Ok") {}
      },
      message: { err in
        Text(err.message)
      }
    )
    .alert(
      "Code sent", isPresented: $handler.isFeedback, presenting: handler.feedback,
      actions: { message in
        Button("Continue") {

        }
      },
      message: { msg in
        Text(msg)
      })
  }
}

struct ConfirmPreviews: PicsPreviewProvider, PreviewProvider {
  static var preview: some View {
    ConfirmView(handler: ConfirmHandler(loginHandler: LoginHandler()))
  }
}
