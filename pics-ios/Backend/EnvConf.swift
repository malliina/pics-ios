import Foundation

class EnvConf {
  static let shared = EnvConf()
  let backendDomain = "pics.malliina.com"
  //    let devBaseUrl = URL(string: "http://192.168.1.119:9000")!
  var prodBaseUrl: URL { URL(string: "https://\(backendDomain)")! }
  var baseUrl: URL { prodBaseUrl }
  //    var baseSocketUrl: URL { URL(string: "ws://192.168.1.119:9000")! }
  var baseSocketUrl: URL { URL(string: "wss://\(backendDomain)")! }
}
