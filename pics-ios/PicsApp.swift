import AWSCognitoIdentityProvider
import SwiftUI
import UIKit

@main
struct PicsApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  private let log = LoggerFactory.shared.vc(PicsVM.self)
  @State var isError = false

  @State var username: Username? = PicsSettings.shared.activeUser

  init() {
    do {
      // Sets up folders, cleans up old pics
      let _ = LocalPics.shared
      try CognitoDelegate.configure()
    } catch {
      log.info("Failed to setup app. \(error)")
      isError = true
    }
    updateNav(user: username)
    log.info("App initialized.")
  }

  var body: some Scene {
    WindowGroup {
      makeAppView()
        .task {
          await Backend.shared.prepare()
        }
    }
  }
  
  @ViewBuilder
  func makeAppView() -> some View {
    if isError {
      OneLinerView(text: "Unable to initialize app.")
    } else {
      NavigationView {
        PicsView(
          viewModel: PicsVM { user in
            DispatchQueue.main.async {
              updateNav(user: user)
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                username = user
              }
            }
          })
      }
      .navigationViewStyle(.stack)
      .id(username)  // https://stackoverflow.com/a/64828640
    }
  }

  private func updateNav(user: Username?) {
    UINavigationBar.appearance().barStyle = user != nil ? .black : .default
  }
}
