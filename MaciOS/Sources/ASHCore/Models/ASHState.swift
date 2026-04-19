import Foundation

public struct ASHState: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
  public static let bitCount = 9
  public static let maxRawValue: UInt16 = 1 << bitCount
  public static let zero = ASHState(rawValue: 0)!

  public let rawValue: UInt16

  public init?(rawValue: UInt16) {
    guard rawValue < Self.maxRawValue else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init?(bits: [UInt8]) {
    guard bits.count == Self.bitCount else {
      return nil
    }

    var value: UInt16 = 0
    for bit in bits {
      guard bit == 0 || bit == 1 else {
        return nil
      }
      value = (value << 1) | UInt16(bit)
    }

    self.init(rawValue: value)
  }

  public init?(bitString: String) {
    let bits = bitString.compactMap { char -> UInt8? in
      switch char {
      case "0":
        return 0
      case "1":
        return 1
      default:
        return nil
      }
    }

    guard bits.count == bitString.count else {
      return nil
    }

    self.init(bits: bits)
  }

  public var bits: [UInt8] {
    (0..<Self.bitCount).map { offset in
      let shift = Self.bitCount - 1 - offset
      return UInt8((rawValue >> UInt16(shift)) & 1)
    }
  }

  public var b8: UInt8 {
    UInt8(rawValue & 1)
  }

  public var description: String {
    bits.map(String.init).joined()
  }

  public func xor(_ other: ASHState) -> ASHState {
    ASHState(rawValue: rawValue ^ other.rawValue)!
  }

  public func hammingWeight() -> Int {
    rawValue.nonzeroBitCount
  }

  public static func < (lhs: ASHState, rhs: ASHState) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
