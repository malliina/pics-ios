import Foundation

protocol LargeIntCodable: Codable {
  init(_ value: Int64)
  var value: Int64 { get }
}

extension LargeIntCodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(Int64.self)
    self.init(raw)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }
}

struct StorageSize: CustomStringConvertible, Comparable, LargeIntCodable {
  static let Zero = StorageSize(bytes: 0)
  static let k: Int = 1024
  static let k64 = Int64(StorageSize.k)

  let bytes: Int64
  var value: Int64 { bytes }

  init(bytes: Int64) {
    self.bytes = bytes
  }

  init(_ value: Int64) {
    self.bytes = value
  }

  init(kilos: Int) {
    self.init(bytes: Int64(kilos) * StorageSize.k64)
  }

  init(megs: Int) {
    self.init(bytes: Int64(megs) * StorageSize.k64 * StorageSize.k64)
  }

  init(gigs: Int) {
    self.init(bytes: Int64(gigs) * StorageSize.k64 * StorageSize.k64 * StorageSize.k64)
  }

  var toBytes: Int64 { bytes }
  var toKilos: Int64 { toBytes / StorageSize.k64 }
  var toMegs: Int64 { toKilos / StorageSize.k64 }
  var toGigs: Int64 { toMegs / StorageSize.k64 }
  var toTeras: Int64 { toGigs / StorageSize.k64 }

  var description: String { return shortDescription }

  var longDescription: String {
    describe(
      "bytes", kilos: "kilobytes", megas: "megabytes", gigas: "gigabytes", teras: "terabytes")
  }

  var shortDescription: String {
    describe("B", kilos: "KB", megas: "MB", gigas: "GB", teras: "TB")
  }

  fileprivate func describe(
    _ bytes: String, kilos: String, megas: String, gigas: String, teras: String
  ) -> String {
    if toTeras >= 10 {
      return "\(toTeras) \(teras)"
    } else if toGigs >= 10 {
      return "\(toGigs) \(gigas)"
    } else if toMegs >= 10 {
      return "\(toMegs) \(megas)"
    } else if toKilos >= 10 {
      return "\(toKilos) \(kilos)"
    } else {
      return "\(toBytes) \(bytes)"
    }
  }

  static func fromBytes(_ bytes: Int64) -> StorageSize? {
    bytes >= 0 ? StorageSize(bytes: Int64(bytes)) : nil
  }

  static func fromBytes(_ bytes: Int) -> StorageSize? {
    bytes >= 0 ? StorageSize(bytes: Int64(bytes)) : nil
  }

  static func fromKilos(_ kilos: Int) -> StorageSize? {
    kilos >= 0 ? StorageSize(kilos: Int(kilos)) : nil
  }

  static func fromMegs(_ megs: Int) -> StorageSize? {
    megs >= 0 ? StorageSize(megs: Int(megs)) : nil
  }

  static func fromGigas(_ gigs: Int) -> StorageSize? {
    gigs >= 0 ? StorageSize(gigs: Int(gigs)) : nil
  }

  public static func == (lhs: StorageSize, rhs: StorageSize) -> Bool {
    lhs.bytes == rhs.bytes
  }

  public static func <= (lhs: StorageSize, rhs: StorageSize) -> Bool {
    lhs.bytes <= rhs.bytes
  }

  public static func < (lhs: StorageSize, rhs: StorageSize) -> Bool {
    lhs.bytes < rhs.bytes
  }

  public static func > (lhs: StorageSize, rhs: StorageSize) -> Bool {
    lhs.bytes > rhs.bytes
  }

  public static func >= (lhs: StorageSize, rhs: StorageSize) -> Bool {
    lhs.bytes >= rhs.bytes
  }

  public static func + (lhs: StorageSize, rhs: StorageSize) -> StorageSize {
    StorageSize(bytes: lhs.bytes + rhs.bytes)
  }

  public static func - (lhs: StorageSize, rhs: StorageSize) -> StorageSize {
    StorageSize(bytes: lhs.bytes - rhs.bytes)
  }
}

extension Int {
  var bytes: StorageSize? { StorageSize.fromBytes(self) }
  var kilos: StorageSize? { StorageSize.fromKilos(self) }
  var megs: StorageSize? { StorageSize.fromMegs(self) }
}

extension UInt64 {
  var bytes: StorageSize { StorageSize(bytes: Int64(self)) }
  var kilos: StorageSize { StorageSize(bytes: Int64(Int64(self) * StorageSize.k64)) }
  var megs: StorageSize {
    StorageSize(bytes: Int64(Int64(self) * StorageSize.k64 * StorageSize.k64))
  }
}
