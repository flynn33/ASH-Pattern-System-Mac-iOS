import Foundation

public protocol ASHRealmEncoderProtocol: AnyObject, Sendable {
  func encode(state: ASHState) -> ASHRealmEncodingResult
}
