import Foundation

public protocol ASHRealmEncoderProtocol: AnyObject {
  func encode(state: ASHState) -> ASHRealmEncodingResult
}
