//
//  ConfirmView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 4.9.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

import Foundation
import SwiftUI
import AWSCognitoIdentityProvider

class ConfirmHandler: ObservableObject {
    let log = LoggerFactory.shared.vc(ConfirmHandler.self)
    var pool: AWSCognitoIdentityUserPool { Tokens.shared.pool }
    
    @Published var confirmError: SignupError? = nil
    @Published var isConfirmError: Bool = false
    
    private let loginHandler: LoginHandler
    var creds: PasswordCredentials? { loginHandler.creds }
    var username: String { creds?.username ?? "" }
    
    init(loginHandler: LoginHandler) {
        self.loginHandler = loginHandler
    }
    
    func submit(code: String) {
        pool.getUser(username).confirmSignUp(code, forceAliasCreation: true).continueWith { (task) -> Any? in
            if let error = SignupError.check(user: self.username, error: task.error) {
                DispatchQueue.main.async {
                    self.confirmError = error
                    self.isConfirmError = true
                }
            } else {
                if let creds = self.creds {
                    self.loginHandler.submit(credentials: creds)
                } else {
                    self.log.info("Code confirmed, but no creds available.")
                }
            }
            return nil
        }
    }
    
    func resendCode() {
        
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
