import Foundation
import SwiftUI

struct ButtonText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .foregroundColor(color.blueish2)
      .frame(minWidth: 220)
      .font(.system(size: 20))
      .padding()
      .cornerRadius(40)
      .overlay(RoundedRectangle(cornerRadius: 40).stroke(color.blueish2, lineWidth: 2))
      .padding()
  }
}

struct BoatTextField: View {
  let title: String
  @Binding var text: String

  init(_ title: String, text: Binding<String>) {
    self.title = title
    self._text = text
  }

  var body: some View {
    TextField(title, text: $text)
      .autocapitalization(.none)
      .disableAutocorrection(true)
      .padding()
      .background(color.inputBackground2)
      .padding()
  }
}

struct BoatPasswordField: View {
  let title: String
  @Binding var password: String

  init(_ title: String, password: Binding<String>) {
    self.title = title
    self._password = password
  }

  var body: some View {
    SecureField(title, text: $password)
      .autocapitalization(.none)
      .padding()
      .foregroundColor(color.almostLight)
      .background(color.inputBackground2)
      .padding(.horizontal)
  }
}
