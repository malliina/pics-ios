import Foundation

enum JsonError: Error {
    static let Key = "error"
    case notJson(Data)
    case missing(String)
    case invalid(String, Any)
}
