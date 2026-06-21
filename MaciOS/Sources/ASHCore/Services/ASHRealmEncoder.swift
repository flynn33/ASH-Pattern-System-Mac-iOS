import Foundation

public final class ASHRealmEncoder: ASHRealmEncoderProtocol {
  private let stateModel: any ASHStateModelProtocol

  public init(stateModel: any ASHStateModelProtocol) {
    self.stateModel = stateModel
  }

  public func encode(state: ASHState) -> ASHRealmEncodingResult {
    guard stateModel.isValid(state) else {
      return .failure(
        ASHRealmEncodingFailureDiagnostic(
          reason: .invalidInputState,
          summary: "Realm encoding requires a valid normalized state.",
          ruleIDs: ["ASH-STATE-VALIDITY-001", "ASH-STATE-REALM-001"],
          notes: [
            "RealmEncoder does not normalize states.",
            "State must be validated by StateModel before encoding."
          ]
        )
      )
    }

    let signature = state.description
    let realmID = String(format: "APS-REALM-%03d", state.rawValue)
    return .success(
      ASHRealmIdentity(
        stateSignature: signature,
        realmID: realmID
      )
    )
  }
}
