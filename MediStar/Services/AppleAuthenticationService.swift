import AuthenticationServices
import CryptoKit
import Foundation
import Security

struct AppleRequestCredentials: Codable, Equatable {
    let identityToken: String
    let rawNonce: String
}

struct AppleSignInSession: Equatable {
    let userID: String
    let name: String
    let email: String
}

enum AppleAuthenticationError: LocalizedError, Equatable {
    case nonceGenerationFailed
    case missingNonce
    case invalidCredential
    case expiredCredential
    case secureStorageFailed
    case noStoredCredential

    var errorDescription: String? {
        switch self {
        case .nonceGenerationFailed, .missingNonce:
            return "MediStar couldn’t start secure Apple sign-in. Please try again."
        case .invalidCredential:
            return "Apple sign-in could not be verified. Please try again."
        case .expiredCredential, .noStoredCredential:
            return "Sign in with Apple again to continue."
        case .secureStorageFailed:
            return "MediStar couldn’t securely save your Apple sign-in. Please try again."
        }
    }
}

enum AppleAuthenticationService {
    private static let nonceCharacters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    static func prepare(_ request: ASAuthorizationAppleIDRequest) throws -> String {
        let rawNonce = try makeNonce()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(rawNonce)
        return rawNonce
    }

    static func complete(
        authorization: ASAuthorization,
        rawNonce: String,
        store: AppleAuthenticationStore = .shared,
        now: Date = .now
    ) throws -> AppleSignInSession {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleAuthenticationError.invalidCredential
        }

        let requestCredentials = try validatedCredentials(
            identityToken: identityToken,
            rawNonce: rawNonce,
            now: now
        )
        try store.save(requestCredentials)

        let formattedName = credential.fullName.map {
            PersonNameComponentsFormatter().string(from: $0)
        } ?? ""
        return AppleSignInSession(
            userID: credential.user,
            name: formattedName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: credential.email ?? ""
        )
    }

    static func makeNonce(length: Int = 32) throws -> String {
        guard length > 0 else { throw AppleAuthenticationError.nonceGenerationFailed }

        var result = ""
        result.reserveCapacity(length)
        let acceptanceLimit = 256 - (256 % nonceCharacters.count)

        while result.count < length {
            var randomBytes = [UInt8](repeating: 0, count: max(16, length - result.count))
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else {
                throw AppleAuthenticationError.nonceGenerationFailed
            }

            for byte in randomBytes where Int(byte) < acceptanceLimit {
                result.append(nonceCharacters[Int(byte) % nonceCharacters.count])
                if result.count == length { break }
            }
        }

        return result
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func validatedCredentials(
        identityToken: String,
        rawNonce: String,
        now: Date = .now
    ) throws -> AppleRequestCredentials {
        guard !rawNonce.isEmpty, rawNonce.count <= 256,
              !rawNonce.contains(where: { $0.isWhitespace || $0.isNewline }),
              !identityToken.isEmpty, identityToken.count <= 8_192,
              !identityToken.contains(where: { $0.isWhitespace || $0.isNewline }) else {
            throw AppleAuthenticationError.invalidCredential
        }

        let segments = identityToken.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let payloadData = base64URLDecoded(String(segments[1])),
              let claims = try? JSONDecoder().decode(AppleIdentityClaims.self, from: payloadData),
              !claims.subject.isEmpty,
              claims.nonce == sha256(rawNonce) else {
            throw AppleAuthenticationError.invalidCredential
        }
        guard claims.expiration > now.timeIntervalSince1970 else {
            throw AppleAuthenticationError.expiredCredential
        }

        return AppleRequestCredentials(identityToken: identityToken, rawNonce: rawNonce)
    }

    private static func base64URLDecoded(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padding))
        return Data(base64Encoded: base64)
    }
}

final class AppleAuthenticationStore {
    static let shared = AppleAuthenticationStore()

    private let service: String
    private let allowsLegacyMigration: Bool
    private let account = "apple-id-token-session"

    init(service: String = "MediStar.AppleAuthentication", allowsLegacyMigration: Bool? = nil) {
        self.service = service
        self.allowsLegacyMigration = allowsLegacyMigration ?? (service == "MediStar.AppleAuthentication")
    }

    func save(_ credentials: AppleRequestCredentials) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(credentials)
        } catch {
            throw AppleAuthenticationError.secureStorageFailed
        }

        let query = baseQuery
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw AppleAuthenticationError.secureStorageFailed
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppleAuthenticationError.secureStorageFailed
        }
    }

    func credentials(now: Date = .now) throws -> AppleRequestCredentials {
        var query = baseQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                guard allowsLegacyMigration else {
                    throw AppleAuthenticationError.noStoredCredential
                }
                return try migrateLegacyCredentials(now: now)
            }
            throw AppleAuthenticationError.secureStorageFailed
        }
        guard let data = item as? Data,
              let stored = try? JSONDecoder().decode(AppleRequestCredentials.self, from: data) else {
            try? deleteCredentials()
            throw AppleAuthenticationError.invalidCredential
        }

        do {
            return try AppleAuthenticationService.validatedCredentials(
                identityToken: stored.identityToken,
                rawNonce: stored.rawNonce,
                now: now
            )
        } catch {
            try? deleteCredentials()
            throw error
        }
    }

    func hasCredentials(now: Date = .now) -> Bool {
        (try? credentials(now: now)) != nil
    }

    func deleteCredentials() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppleAuthenticationError.secureStorageFailed
        }
    }

    private func migrateLegacyCredentials(now: Date) throws -> AppleRequestCredentials {
        let legacyService = ["Pill", "Mate", ".AppleAuthentication"].joined()
        let legacyStore = AppleAuthenticationStore(service: legacyService, allowsLegacyMigration: false)
        let credentials = try legacyStore.credentials(now: now)
        try save(credentials)
        try? legacyStore.deleteCredentials()
        return credentials
    }

    func clearCredentials() {
        try? deleteCredentials()
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}

private struct AppleIdentityClaims: Decodable {
    let subject: String
    let nonce: String
    let expiration: TimeInterval

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case nonce
        case expiration = "exp"
    }
}
