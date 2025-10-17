import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
import UIKit

enum GoogleAuthBridge {
  static func signIn(
    completion: @escaping (_ idToken: String, _ accessToken: String) -> Void,
    onError: @escaping (Error) -> Void
  ) {
    let clientID = MAEnv.googleClientID
    guard clientID.isEmpty == false && clientID.hasPrefix("<") == false else {
      onError(NSError(
        domain: "GoogleAuthBridge",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "Configura MAEnv.googleClientID con tu OAuth Client ID de Google."]
      ))
      return
    }

    if GIDSignIn.sharedInstance.configuration?.clientID != clientID {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    guard
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }),
      let root = windowScene.keyWindow ?? windowScene.windows.first(where: \.isKeyWindow),
      let presenter = root.rootViewController
    else {
      onError(NSError(domain: "GoogleAuthBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se encontró una ventana activa"]))
      return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
      if let error { onError(error); return }
      guard
        let user = result?.user,
        let idToken = user.idToken?.tokenString
      else {
        onError(NSError(domain: "GoogleAuthBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "Google no entregó idToken"]))
        return
      }
      completion(idToken, user.accessToken.tokenString)
    }
  }
}
#endif
