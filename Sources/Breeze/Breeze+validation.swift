import Foundation
import StoreKit

extension Breeze {
    // MARK: - Validation related
    /// Validates a JWT token using RSA public key (ES256)
    /// - Parameters:
    ///   - token: The JWT token string to validate
    ///   - publicKeyString: The RSA public key in PEM format
    /// - Returns: Bool indicating if the token is valid
    /// - Throws: Error if validation fails
    public func validateJWT(token: String) throws -> BreezeTokenPayload {
        // Split the JWT into its components
        let components = token.components(separatedBy: ".")
        guard components.count == 3 else {
            throw BreezeError.invalidToken
        }
        let publicKeyString = BreezeConstants.API.apiPublicKey //trusted Breeze JWT
        
        // Get the header and payload
        let header = components[0]
        let payload = components[1]
        let signature = components[2]
        print("token retrieved: \(token)")
        
        // Create the signing input
        let signingInput = "\(header).\(payload)"

        // Convert public key string to SecKey - better PEM parsing
        let cleanedPublicKey = publicKeyString
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let publicKeyData = Data(base64Encoded: cleanedPublicKey) else {
            print("error1: Failed to decode base64 public key")
            throw BreezeError.invalidToken
        }

        var error: Unmanaged<CFError>?

        // Try with raw X.509 data first (iOS handles this automatically)
        var publicKey = SecKeyCreateWithData(publicKeyData as CFData,
                                        [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                                            kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary,
                                        &error)

        // If that fails, try extracting raw key data
        if publicKey == nil {
            print("X.509 format failed, trying raw key extraction...")
            guard let rawKeyData = extractRawPublicKeyFromX509(publicKeyData) else {
                print("error2: Failed to extract raw public key from X.509 format")
                throw BreezeError.invalidToken
            }
            
            print("Raw key data length: \(rawKeyData.count)")
            print("Raw key data (hex): \(rawKeyData.map { String(format: "%02x", $0) }.joined())")
            
            let keyAttributes: [CFString: Any] = [
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeyClass: kSecAttrKeyClassPublic,
                kSecAttrKeySizeInBits: 256
            ]
            
            publicKey = SecKeyCreateWithData(rawKeyData as CFData,
                                        keyAttributes as CFDictionary,
                                        &error)
        }

        guard let finalPublicKey = publicKey else {
            print("error2: EC public key creation from data failed")
            if let error = error {
                print("Key creation error: \(error.takeRetainedValue())")
            }
            throw BreezeError.invalidToken
        }

        publicKey = finalPublicKey

        // Convert signature from base64url to base64
        guard let signatureData = Data(base64Encoded: signature.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((signature.count + 3) / 4) * 4, withPad: "=", startingAt: 0)) else {
            print("error: invalid signature base64url encoding")
            throw BreezeError.invalidToken
        }

        // ES256 uses ECDSA with SHA-256, not RSA
        let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256

        // Verify the signature
        guard SecKeyVerifySignature(publicKey!,
                                algorithm,
                                signingInput.data(using: .utf8)! as CFData,
                                signatureData as CFData,
                                &error) else {
            print("error3: signature verification failed")
            if let error = error {
                print("Verification error: \(error.takeRetainedValue())")
            }
            throw BreezeError.invalidToken
        }

        // Decode and parse the payload
        guard let payloadData = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
            let payloadString = String(data: payloadData, encoding: .utf8),
            let payloadJson = try? JSONDecoder().decode(BreezeTokenPayload.self, from: payloadData) else {
                        print("error4: payload decoding failed")
            throw BreezeError.invalidToken
        }
        print("payloadJson: \(String(describing: payloadJson))")
        
        return payloadJson
    }
}

// Extract raw public key from X.509 SubjectPublicKeyInfo format
func extractRawPublicKeyFromX509(_ data: Data) -> Data? {
    // X.509 SubjectPublicKeyInfo for P-256 has this structure:
    // The actual public key starts after the ASN.1 header
    // For P-256, the raw key is 65 bytes (0x04 + 32 bytes X + 32 bytes Y)
    
    // Look for the 0x04 byte which indicates uncompressed point format
    guard let range = data.range(of: Data([0x04])) else {
        return nil
    }
    
    let startIndex = range.lowerBound
    // P-256 uncompressed public key is 65 bytes (1 + 32 + 32)
    guard startIndex + 65 <= data.count else {
        return nil
    }
    
    return data.subdata(in: startIndex..<(startIndex + 65))
}
