//
//  SignupView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 3.9.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

class SignupHandler: ObservableObject {
    let log = LoggerFactory.shared.vc(SignupHandler.self)
    
    @Published var isSignUpError: Bool = false
    
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    static func build(completion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?) -> SignupHandler {
        let h = SignupHandler()
        h.passwordAuthenticationCompletion = completion
        return h
    }
    
    func signUp(creds: PasswordCredentials) {
        let username = creds.username
        let attributes = [
            AWSCognitoIdentityUserAttributeType(name: "email", value: username)
        ]
        pool.signUp(username, password: creds.password, userAttributes: attributes, validationData: nil).continueWith { (task) -> Any? in
            self.handleSignupResult(creds: creds, task: task)
            return nil
        }
    }
    
    func handleSignupResult(creds: PasswordCredentials, task: AWSTask<AWSCognitoIdentityUserPoolSignUpResponse>) {
        if let error = SignupError.check(user: creds.username, error: task.error) {
            DispatchQueue.main.async {
                self.isSignUpError = true
            }
        } else {
            if let response = task.result, let name = response.user.username {
                self.log.info("Created \(name).")
                if response.user.confirmedStatus == .confirmed {
                    // dismiss sheet here, then run this after dismissal
                    self.passwordAuthenticationCompletion?.set(result: creds.toCognito())
                } else {
                    self.log.info("Going to confirm page for \(name)...")
//                    self.presentModally(vc: ConfirmVC(user: name, onSuccess: self.onSignupDone))
                }
            }
        }
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
            .alert(isPresented: $handler.isSignUpError) {
                Alert(title: Text("Authentication error"), message: Text("Failed to sign up."), dismissButton: .default(Text("Ok")))
            }
            .environment(\.colorScheme, .dark)
        }
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 12 mini", "iPad Pro (11-inch) (3rd generation)"], id: \.self) { deviceName in
            SignupView(handler: SignupHandler())
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
