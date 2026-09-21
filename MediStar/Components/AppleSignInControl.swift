import AuthenticationServices
import SwiftUI

struct AppleSignInControl: View {
    let onSuccess: (AppleSignInSession) -> Void
    let onFailure: (String) -> Void

    @State private var pendingNonce: String?

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            do {
                pendingNonce = try AppleAuthenticationService.prepare(request)
            } catch {
                pendingNonce = nil
                onFailure(error.localizedDescription)
            }
        } onCompletion: { result in
            complete(result)
        }
        .signInWithAppleButtonStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .accessibilityHint("Sign in securely using your Apple ID")
    }

    private func complete(_ result: Result<ASAuthorization, Error>) {
        defer { pendingNonce = nil }

        switch result {
        case .success(let authorization):
            guard let pendingNonce else {
                onFailure(AppleAuthenticationError.missingNonce.localizedDescription)
                return
            }
            do {
                onSuccess(
                    try AppleAuthenticationService.complete(
                        authorization: authorization,
                        rawNonce: pendingNonce
                    )
                )
            } catch {
                onFailure(error.localizedDescription)
            }
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            onFailure("Apple sign-in could not be completed. Please try again.")
        }
    }
}
