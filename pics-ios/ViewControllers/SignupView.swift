import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

struct AuthUser: Identifiable {
    let username: String
    var id: String { username }
}

extension AWSCognitoIdentityUserPool {
    func signUpAsync(_ creds: PasswordCredentials) async throws -> AWSCognitoIdentityUser {
        let username = creds.username
        let attributes = [
            AWSCognitoIdentityUserAttributeType(name: "email", value: username)
        ]
        return try await withCheckedThrowingContinuation { cont in
            signUp(username, password: creds.password, userAttributes: attributes, validationData: nil).continueWith { task in
                if let error = SignupError.check(user: username, error: task.error) {
                    cont.resume(throwing: error)
                } else if let user = task.result?.user {
                    cont.resume(returning: user)
                } else {
                    cont.resume(throwing: SignupError.unknown)
                }
                return nil
            }
        }
    }
}

class SignupHandler: ObservableObject {
    let log = LoggerFactory.shared.vc(SignupHandler.self)
    
    @Published var signUpError: SignupError? = nil
    @Published var isSignUpError: Bool = false
    
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    var loginHandler: LoginHandler
    
    init(loginHandler: LoginHandler) {
        self.loginHandler = loginHandler
    }
    
    func signUp(creds: PasswordCredentials) {
        loginHandler.creds = creds
        Task {
            do {
                let user = try await self.pool.signUpAsync(creds)
                if let name = user.username {
                    self.log.info("Created \(name).")
                    if user.confirmedStatus == .confirmed {
                        loginHandler.submit(credentials: creds)
                    } else {
                        self.log.info("Going to confirm page for \(name)...")
                        await onConfirm()
                    }
                } else {
                    throw SignupError.unknown
                }
            } catch let error {
                log.info("\(error)")
                let signupFailure = error as? SignupError ?? SignupError.unknown
                await onFailure(signupFailure)
            }
        }
    }
    
    @MainActor func onConfirm() {
        loginHandler.showSignUp = false
        loginHandler.showConfirm = true
    }
    
    @MainActor func onFailure(_ error: SignupError) {
        signUpError = error
        isSignUpError = true
    }
}

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var handler: SignupHandler
    
    @State var username: String = ""
    @State var password: String = ""
    @State var passwordAgain: String = ""
    
    var body: some View {
        ZStack {
            PicsColors.background
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Text("A valid email address is required. The minimum password length is 7 characters.")
                    .foregroundColor(PicsColors.almostLight)
                TextField("Email", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(PicsColors.inputBackground2)
                    .padding()
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                    .padding()
                    .foregroundColor(PicsColors.almostLight)
                    .background(PicsColors.inputBackground2)
                    .padding(.horizontal)
                SecureField("Repeat password", text: $passwordAgain)
                    .autocapitalization(.none)
                    .padding()
                    .foregroundColor(PicsColors.almostLight)
                    .background(PicsColors.inputBackground2)
                    .padding(.horizontal)
                Button {
                    guard username != "" else { return }
                    guard password != "" else { return }
                    guard password == passwordAgain else { return }
                    let creds = PasswordCredentials(user: username, pass: password)
                    handler.signUp(creds: creds)
                } label: {
                    Text("Sign up")
                        .foregroundColor(PicsColors.blueish2)
                        .frame(minWidth: 220)
                        .font(.system(size: 20))
                        .padding()
                        .cornerRadius(40)
                        .overlay(RoundedRectangle(cornerRadius: 40).stroke(PicsColors.blueish2, lineWidth: 2))
                        .padding()
                }
                Spacer()
            }
            .frame(maxWidth: 400)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(PicsColors.blueish2)
                    }
                }
            }
            .alert("Sign up error", isPresented: $handler.isSignUpError, presenting: handler.signUpError, actions: { t in
                Button("Ok") {
                    
                }
            }, message: { err in
                Text(err.message)
            })
            .environment(\.colorScheme, .dark)
        }
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            SignupView(handler: SignupHandler(loginHandler: LoginHandler()))
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
