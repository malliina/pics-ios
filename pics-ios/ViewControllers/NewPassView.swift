//
//  NewPassView.swift
//  pics-ios
//
//  Created by Michael Skogberg on 5.9.2022.
//  Copyright © 2022 Michael Skogberg. All rights reserved.
//

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
            PicsColors.background
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Text("Enter a new password.")
                    .foregroundColor(PicsColors.almostLight)
                SecureField("Password", text: $password)
                    .autocapitalization(.none)
                    .padding()
                    .foregroundColor(PicsColors.almostLight)
                    .background(PicsColors.inputBackground2)
                    .padding(.horizontal)
                Button {
                    guard password != "" else { return }
                    handler.save(password: password)
                } label: {
                    Text("Save")
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
