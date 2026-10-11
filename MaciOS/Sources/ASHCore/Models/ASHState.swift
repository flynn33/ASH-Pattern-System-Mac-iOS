import Foundation

public struct ASHState: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
  public static let bitCount = 9
  public static let maxRawValue: UInt16 = 1 << bitCount
  public static let zero = ASHState(validatedRawValue: 0)

  public let rawValue: UInt16

  private enum CodingKeys: String, CodingKey { case rawValue }

  private init(validatedRawValue: UInt16) {
    self.rawValue = validatedRawValue
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let value = try container.decode(UInt16.self, forKey: .rawValue)
    guard let state = Self(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        forKey: .rawValue, in: container,
        debugDescription: "ASHState.rawValue must be in 0...511; received \(value)."
      )
    }
    self = state
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rawValue, forKey: .rawValue)
  }

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
    guard bitString.utf8.count == Self.bitCount else { return nil }
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
    // XOR of two nine-bit values is itself a nine-bit value.
    ASHState(validatedRawValue: rawValue ^ other.rawValue)
  }

  public func hammingWeight() -> Int {
    rawValue.nonzeroBitCount
  }

  public static func < (lhs: ASHState, rhs: ASHState) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
