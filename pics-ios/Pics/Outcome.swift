import Foundation

enum Outcome<T> {
    case failure(AppError)
    case success(T)
    
    static func fail<T>(_ l: AppError) -> Outcome<T> {
        .failure(l)
    }
    
    static func succeed<T>(_ r: T) -> Outcome<T> {
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
