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

class LoginHandler: NSObject, AWSCognitoIdentityPasswordAuthentication {
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    func submit(credentials: PasswordCredentials) {
        passwordAuthenticationCompletion?.set(result: credentials.toCognito())
    }
    
    func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        let username = ""
        if let authError = SignupError.check(user: username, error: error) {
            if case .userNotConfirmed(let user) = authError {
//                self.presentModally(vc: ConfirmVC(user: user, onSuccess: self.loginWithCurrentInput))
            } else {
//                self.presentError(error: authError)
            }
        } else {
//            self.username.text = nil
//            self.password.text = nil
//            self.root?.changeStyle(dark: true)
//            self.dismiss(animated: true, completion: nil)
        }
    }
}

struct LoginView: View {
    let log = LoggerFactory.shared.vc(LoginView.self)
    @Environment(\.dismiss) private var dismiss
    
    @State var username: String = ""
    @State var password: String = ""
    
    var handler: LoginHandler
    
    func loginAs(credentials: PasswordCredentials) {
        log.info("Attempting login as \(credentials.username)...")
        handler.submit(credentials: credentials)
    }
    
    var body: some View {
        ZStack {
            PicsColors.background
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Text("Log in to your personal gallery. Images are always public.")
                    .foregroundColor(PicsColors.almostLight)
                TextField("Username", text: $username)
                    .autocapitalization(.none)
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
            .background(PicsColors.almostBlack)
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
