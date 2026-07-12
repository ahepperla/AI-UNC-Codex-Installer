import Foundation
import Security

final class KeychainManager: @unchecked Sendable {
    static let serviceName = "UNC_AZURE_API_KEY"

    private let accountName: String

    init(accountName: String = NSUserName()) {
        self.accountName = accountName
    }

    func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidString
        }

        let query = baseQuery()

        if apiKeyExists() {
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.securityError(updateStatus)
            }
            return
        }

        var attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        if let access = makeAccessForEnvironmentLoader() {
            attributes[kSecAttrAccess as String] = access
        } else {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard retryStatus == errSecSuccess else {
                throw KeychainError.securityError(retryStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainError.securityError(status)
        }
    }

    func readAPIKey() throws -> String {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw KeychainError.securityError(status)
        }
        guard let data = item as? Data, let apiKey = String(data: data, encoding: .utf8), !apiKey.isEmpty else {
            throw KeychainError.invalidString
        }
        return apiKey
    }

    func apiKeyExists() -> Bool {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = false
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.securityError(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: accountName
        ]
    }

    private func makeAccessForEnvironmentLoader() -> SecAccess? {
        let trustedApplications = [
            trustedApplication(path: nil),
            trustedApplication(path: "/usr/bin/security")
        ].compactMap { $0 }

        guard !trustedApplications.isEmpty else { return nil }

        var access: SecAccess?
        let status = SecAccessCreate(
            Self.serviceName as CFString,
            trustedApplications as CFArray,
            &access
        )
        return status == errSecSuccess ? access : nil
    }

    private func trustedApplication(path: String?) -> SecTrustedApplication? {
        var application: SecTrustedApplication?
        let status: OSStatus

        if let path {
            status = path.withCString { SecTrustedApplicationCreateFromPath($0, &application) }
        } else {
            status = SecTrustedApplicationCreateFromPath(nil, &application)
        }

        return status == errSecSuccess ? application : nil
    }
}

enum KeychainError: LocalizedError {
    case invalidString
    case securityError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidString:
            return "The API key could not be encoded or decoded."
        case .securityError(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain returned OSStatus \(status)."
        }
    }
}
