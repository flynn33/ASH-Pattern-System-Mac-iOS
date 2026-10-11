import Foundation

public struct ASHRationalAverage: Codable, Hashable, Sendable {
  public let numerator: Int64
  public let denominator: Int64
  public init(numerator: Int64, denominator: Int64 = 16) { self.numerator = numerator; self.denominator = denominator }
}
public enum ASHAveragingError: Error, Equatable, Sendable { case incompleteValues, integerOverflow, nonfiniteValue }
extension ASHStateModel {
  /// Exact unreduced rational average over the sixteen canonical translations.
  public func average(at state: ASHState, values: [ASHState:Int64]) throws -> ASHRationalAverage {
    let orbit = reachableStates(from:state)
    var total:Int64 = 0
    for member in orbit {
      guard let value = values[member] else { throw ASHAveragingError.incompleteValues }
      let next = total.addingReportingOverflow(value)
      guard !next.overflow else { throw ASHAveragingError.integerOverflow }
      total = next.partialValue
    }
    return .init(numerator:total)
  }
  public func average(at state: ASHState, values: [ASHState:Double]) throws -> Double {
    var total:Double = 0
    for member in reachableStates(from:state) {
      guard let value = values[member] else { throw ASHAveragingError.incompleteValues }
      guard value.isFinite else { throw ASHAveragingError.nonfiniteValue }
      total += value / 16
      guard total.isFinite else { throw ASHAveragingError.nonfiniteValue }
    }
    return total
  }
}
