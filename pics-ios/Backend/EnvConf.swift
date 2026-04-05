import Foundation

struct EnvConf {
  static func make(host: String, logsHost: String, secure: Bool) -> EnvConf {
    let suffix = secure ? "s" : ""
    return EnvConf(
      host: host,
      baseUrl: URL(string: "http\(suffix)://\(host)")!,
      logsUrl: URL(string: "http\(suffix)://\(logsHost)")!,
      socketUrl: URL(string: "ws\(suffix)://\(host)")!
    )
  }
  static let dev = EnvConf.make(host: "localhost:9000", logsHost: "localhost:9001", secure: false)
  static let prod = EnvConf.make(host: "pics.malliina.com", logsHost: "logs.malliina.com", secure: true)
  static let shared = prod
  
  let host: String
  let baseUrl: URL
  let logsUrl: URL
  let socketUrl: URL
}
