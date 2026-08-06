import Foundation
import Security

final class DeviceDekKeystore {
    private let tagPrefix = "onl.coconut.wallet.hot-wallet.device."
    private let algorithm = SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM

    func wrap(alias: String, plaintext: Data) throws -> Data {
        let privateKey = try loadOrCreatePrivateKey(alias: alias)
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm) else {
            throw NSError(
                domain: "DeviceDekKeystore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Secure Enclave algorithm unavailable"]
            )
        }
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            publicKey,
            algorithm,
            plaintext as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }
        return encrypted as Data
    }

    func unwrap(alias: String, ciphertext: Data) throws -> Data {
        guard let privateKey = loadPrivateKey(alias: alias),
              SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
            throw NSError(
                domain: "DeviceDekKeystore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Secure Enclave key not found"]
            )
        }
        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            algorithm,
            ciphertext as CFData,
            &error
        ) else {
            throw error!.takeRetainedValue() as Error
        }
        return decrypted as Data
    }

    func delete(alias: String) {
        SecItemDelete([
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag(alias),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        ] as CFDictionary)
    }

    private func loadOrCreatePrivateKey(alias: String) throws -> SecKey {
        if let key = loadPrivateKey(alias: alias) {
            return key
        }

        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &accessError
        ) else {
            throw accessError!.takeRetainedValue() as Error
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag(alias),
                kSecAttrAccessControl as String: access,
            ],
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return key
    }

    private func loadPrivateKey(alias: String) -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag(alias),
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
            return nil
        }
        return (item as! SecKey)
    }

    private func tag(_ alias: String) -> Data {
        "\(tagPrefix)\(alias)".data(using: .utf8)!
    }
}
