//
//  LoginView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 3.9.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

class LoginHandler: NSObject, ObservableObject, AWSCognitoIdentityPasswordAuthentication {
    let log = LoggerFactory.shared.vc(LoginHandler.self)
    
    @Published var signupError: SignupError? = nil
    @Published var isAuthError: Bool = false
    @Published var showSignUp: Bool = false
    @Published var showConfirm: Bool = false
    
    @Published var showNewPass: Bool = false
    @Published var newPassError: SignupError? = nil
    @Published var isNewPassError: Bool = false
    
    @Published var isComplete: Bool = false
    @Published var isNewPassComplete: Bool = false
    
    var creds: PasswordCredentials? = nil
    
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    var newPassCompletion: AWSTaskCompletionSource<AWSCognitoIdentityNewPasswordRequiredDetails>? = nil
    
    func submit(credentials: PasswordCredentials) {
        creds = credentials
        passwordAuthenticationCompletion?.set(result: credentials.toCognito())
    }
    
    func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        if let authError = SignupError.check(user: creds?.username ?? "", error: error) {
            if case .userNotConfirmed(let user) = authError {
                log.info("User \(user) not confirmed.")
                DispatchQueue.main.async {
                    self.showConfirm = true
                }
            } else {
                log.info("Auth failed.")
                DispatchQueue.main.async {
                    self.isAuthError = true
                }
            }
        } else {
            log.info("Login completed without error.")
            DispatchQueue.main.async {
                self.showSignUp = false
                self.showConfirm = false
                self.isComplete = true
            }
        }
    }
}

extension LoginHandler: AWSCognitoIdentityNewPasswordRequired {
    func getNewPasswordDetails(_ newPasswordRequiredInput: AWSCognitoIdentityNewPasswordRequiredInput, newPasswordRequiredCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityNewPasswordRequiredDetails>) {
        self.newPassCompletion = newPasswordRequiredCompletionSource
    }
    
    func save(password: String) {
        let newPassDetails = AWSCognitoIdentityNewPasswordRequiredDetails(proposedPassword: password, userAttributes: [:])
        // triggers didCompleteNewPasswordStepWithError
        newPassCompletion?.set(result: newPassDetails)
    }
    
    func didCompleteNewPasswordStepWithError(_ error: Error?) {
        DispatchQueue.main.async {
            if let error = SignupError.check(user: self.creds?.username ?? "", error: error) {
                self.newPassError = error
                self.isNewPassError = true
            } else {
                self.isNewPassComplete = true
            }
        }
    }
}

struct LoginView: View {
    let log = LoggerFactory.shared.vc(LoginView.self)
    @Environment(\.dismiss) private var dismiss
    
    @State var username: String = ""
    @State var password: String = ""
    
    @ObservedObject var handler: LoginHandler
    
    var body: some View {
        if handler.isComplete {
            ProgressView().onAppear {
                dismiss()
            }
        } else {
            ZStack {
                PicsColors.background
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    Text("Log in to your personal gallery. Images are always public.")
                        .foregroundColor(PicsColors.almostLight)
                    TextField("Username", text: $username)
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
                    Button {
                        log.info("Logging in with current input")
                        guard username != "" else { return }
                        guard password != "" else { return }
                        handler.submit(credentials: PasswordCredentials(user: username, pass: password))
                    } label: {
                        Text("Log in")
                            .foregroundColor(PicsColors.blueish2)
                            .frame(minWidth: 220)
                            .font(.system(size: 20))
                            .padding()
                            .cornerRadius(40)
                            .overlay(RoundedRectangle(cornerRadius: 40).stroke(PicsColors.blueish2, lineWidth: 2))
                            .padding()
                    }
                    Spacer()
                    Button {
                        handler.showSignUp = true
                    } label: {
                        Text("Sign up")
                            .foregroundColor(PicsColors.blueish2)
                            .frame(minWidth: 220)
                            .padding()
                            .cornerRadius(40)
                            .overlay(RoundedRectangle(cornerRadius: 40).stroke(PicsColors.blueish2, lineWidth: 2))
                            .padding()
                    }
                }
                .frame(maxWidth: 400)
                .environment(\.colorScheme, .dark)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .foregroundColor(PicsColors.blueish2)
                        }
                    }
                }.alert(isPresented: $handler.isAuthError) {
                    Alert(title: Text("Authentication error"), message: Text("Failed to log in."), dismissButton: .default(Text("Ok")))
                }.sheet(isPresented: $handler.showSignUp) {
                    NavigationView {
                        SignupView(handler: SignupHandler(loginHandler: handler))
                    }
                }.sheet(isPresented: $handler.showConfirm) {
                    NavigationView {
                        ConfirmView(handler: ConfirmHandler(loginHandler: handler))
                    }
                }
//                .sheet(isPresented: $handler.showNewPass) {
//                    NavigationView {
//                        NewPassView(handler: handler)
//                    }
//                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            LoginView(handler: LoginHandler())
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
