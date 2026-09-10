import Foundation
import Security

final class DeviceDekKeystore {
    private let tagPrefix = "onl.coconut.wallet.hot-wallet.device."
    private let algorithm = SecKeyAlgorithm.eciesEncryptionCofactorX963SHA256AESGCM

    func wrap(alias: String, plaintext: Data) throws -> Data {
        do {
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
        } catch {
            // A permanent Secure Enclave key may exist even though wrapping
            // failed. Deletion is safe when no key was created.
            delete(alias: alias)
            throw error
        }
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

    func getAliases() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw NSError(
                domain: "DeviceDekKeystore",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Unable to enumerate Secure Enclave key aliases"]
            )
        }

        let attributes: [[String: Any]]
        if let itemList = items as? [[String: Any]] {
            attributes = itemList
        } else if let item = items as? [String: Any] {
            attributes = [item]
        } else {
            attributes = []
        }
        return attributes.compactMap { item in
            guard let tagData = item[kSecAttrApplicationTag as String] as? Data,
                  let fullTag = String(data: tagData, encoding: .utf8),
                  fullTag.hasPrefix(tagPrefix) else {
                return nil
            }
            return String(fullTag.dropFirst(tagPrefix.count))
        }
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
