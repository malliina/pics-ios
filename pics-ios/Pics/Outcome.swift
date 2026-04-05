import Foundation

enum Outcome<T> {
  case failure(AppError)
  case success(T)

  static func fail<U>(_ l: AppError) -> Outcome<U> {
    .failure(l)
  }

  static func succeed<U>(_ r: U) -> Outcome<U> {
    .success(r)
  }
}

extension Outcome {
  func map<U>(_ code: (T) -> U) -> Outcome<U> {
    switch self {
    case .failure(let appError): return Outcome.fail(appError)
    case .success(let t): return Outcome.succeed(code(t))
    }
  }
}
