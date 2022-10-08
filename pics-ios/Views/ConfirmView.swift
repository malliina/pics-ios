import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

extension AWSCognitoIdentityUser {
    func confirmSignUpAsync(username: String, code: String) async throws -> AWSCognitoIdentityUserConfirmSignUpResponse {
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
            PicsColors.background
                .edgesIgnoringSafeArea(.all)
            VStack {
                Text("Enter the code sent to the provided email address.")
                TextField("Username", text: .constant(handler.username))
                    .disabled(true)
                    .autocapitalization(.none)
                    .padding()
                    .background(PicsColors.inputBackground2)
                    .padding()
                TextField("Code", text: $code)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(PicsColors.inputBackground2)
                    .padding()
                Button {
                    guard code != "" else { return }
                    handler.submit(code: code)
                } label: {
                    Text("Confirm")
                        .foregroundColor(PicsColors.blueish2)
                        .frame(minWidth: 220)
                        .font(.system(size: 20))
                        .padding()
                        .cornerRadius(40)
                        .overlay(RoundedRectangle(cornerRadius: 40).stroke(PicsColors.blueish2, lineWidth: 2))
                        .padding()
                }
                Button {
                    handler.resendCode()
                } label: {
                    Text("Resend code").foregroundColor(PicsColors.blueish2)
                }
            }
            .frame(maxWidth: 400)
            .environment(\.colorScheme, .dark)
        }.alert("Code error", isPresented: $handler.isConfirmError, presenting: handler.confirmError, actions: { t in
            Button("Ok") { }
        }, message: { err in
            Text(err.message)
        })
        .alert("Code sent", isPresented: $handler.isFeedback, presenting: handler.feedback, actions: { message in
            Button("Continue") {
                
            }
        }, message: { msg in
            Text(msg)
        })
    }
}

struct ConfirmView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            ConfirmView(handler: ConfirmHandler(loginHandler: LoginHandler()))
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
