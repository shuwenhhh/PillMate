import AuthenticationServices
import Foundation
import XCTest
@testable import MediStar

@MainActor
final class AppleAuthenticationServiceTests: XCTestCase {
    func testPrepareSetsHashedNonceAndRequestedScopes() throws {
        let request = ASAuthorizationAppleIDProvider().createRequest()

        let rawNonce = try AppleAuthenticationService.prepare(request)

        XCTAssertEqual(request.nonce, AppleAuthenticationService.sha256(rawNonce))
        XCTAssertEqual(Set(request.requestedScopes ?? []), Set([.fullName, .email]))
    }

    func testNonceIsUniqueAndUsesHeaderSafeCharacters() throws {
        let first = try AppleAuthenticationService.makeNonce(length: 64)
        let second = try AppleAuthenticationService.makeNonce(length: 64)
        let allowed = CharacterSet(
            charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )

        XCTAssertEqual(first.count, 64)
        XCTAssertEqual(second.count, 64)
        XCTAssertNotEqual(first, second)
        XCTAssertNil(first.unicodeScalars.first(where: { !allowed.contains($0) }))
        XCTAssertNil(second.unicodeScalars.first(where: { !allowed.contains($0) }))
    }

    func testSHA256MatchesKnownValue() {
        XCTAssertEqual(
            AppleAuthenticationService.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testCredentialValidationRequiresMatchingNonceAndFutureExpiry() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rawNonce = "one-time-nonce"
        let token = makeToken(
            subject: "apple-user-1",
            nonce: AppleAuthenticationService.sha256(rawNonce),
            expiration: now.timeIntervalSince1970 + 300
        )

        XCTAssertEqual(
            try AppleAuthenticationService.validatedCredentials(
                identityToken: token,
                rawNonce: rawNonce,
                now: now
            ),
            AppleRequestCredentials(identityToken: token, rawNonce: rawNonce)
        )

        XCTAssertThrowsError(
            try AppleAuthenticationService.validatedCredentials(
                identityToken: token,
                rawNonce: "wrong-nonce",
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? AppleAuthenticationError, .invalidCredential)
        }

        XCTAssertThrowsError(
            try AppleAuthenticationService.validatedCredentials(
                identityToken: token,
                rawNonce: rawNonce,
                now: now.addingTimeInterval(301)
            )
        ) { error in
            XCTAssertEqual(error as? AppleAuthenticationError, .expiredCredential)
        }
    }

    func testKeychainRoundTripAndDeletion() throws {
        let store = AppleAuthenticationStore(
            service: "MediStarTests.AppleAuthentication.\(UUID().uuidString)"
        )
        defer { store.clearCredentials() }

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rawNonce = "keychain-nonce"
        let token = makeToken(
            subject: "apple-user-2",
            nonce: AppleAuthenticationService.sha256(rawNonce),
            expiration: now.timeIntervalSince1970 + 300
        )
        let credentials = AppleRequestCredentials(identityToken: token, rawNonce: rawNonce)

        try store.save(credentials)

        XCTAssertEqual(try store.credentials(now: now), credentials)
        XCTAssertTrue(store.hasCredentials(now: now))

        try store.deleteCredentials()

        XCTAssertThrowsError(try store.credentials(now: now)) { error in
            XCTAssertEqual(error as? AppleAuthenticationError, .noStoredCredential)
        }
    }

    func testExpiredKeychainCredentialIsRemoved() throws {
        let store = AppleAuthenticationStore(
            service: "MediStarTests.AppleAuthentication.\(UUID().uuidString)"
        )
        defer { store.clearCredentials() }

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rawNonce = "expired-keychain-nonce"
        let token = makeToken(
            subject: "apple-user-3",
            nonce: AppleAuthenticationService.sha256(rawNonce),
            expiration: now.timeIntervalSince1970 - 1
        )
        try store.save(AppleRequestCredentials(identityToken: token, rawNonce: rawNonce))

        XCTAssertThrowsError(try store.credentials(now: now)) { error in
            XCTAssertEqual(error as? AppleAuthenticationError, .expiredCredential)
        }
        XCTAssertThrowsError(try store.credentials(now: now)) { error in
            XCTAssertEqual(error as? AppleAuthenticationError, .noStoredCredential)
        }
    }

    private func makeToken(
        subject: String,
        nonce: String,
        expiration: TimeInterval
    ) -> String {
        let header = base64URL(Data(#"{"alg":"RS256","kid":"test"}"#.utf8))
        let payloadObject: [String: Any] = [
            "sub": subject,
            "nonce": nonce,
            "exp": expiration
        ]
        let payload = base64URL(try! JSONSerialization.data(withJSONObject: payloadObject))
        return "\(header).\(payload).test-signature"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
