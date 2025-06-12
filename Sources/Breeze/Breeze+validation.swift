import Foundation
import StoreKit

extension Breeze {
    // MARK: - Validation related
    /// Validates a JWT token using RSA public key
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
        
        // Convert public key string to SecKey
        guard let publicKeyData = Data(base64Encoded: publicKeyString.replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----\n", with: "")
            .replacingOccurrences(of: "\n-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")) else {
                print("error1")
            throw BreezeError.invalidToken
        }
        
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyData as CFData,
                                                 [kSecAttrKeyType: kSecAttrKeyTypeRSA,
                                                  kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary,
                                                 &error) else {
                                                                    print("error2")
            throw BreezeError.invalidToken
        }
        
        // Convert signature from base64url to base64
        let signatureData = Data(base64Encoded: signature.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((signature.count + 3) / 4) * 4, withPad: "=", startingAt: 0))!
        
        // Create algorithm
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        
        // Verify the signature
        guard SecKeyVerifySignature(publicKey,
                                  algorithm,
                                  signingInput.data(using: .utf8)! as CFData,
                                  signatureData as CFData,
                                  &error) else {
            print("error3")
            throw BreezeError.invalidToken
        }
        
        // Decode and parse the payload
        guard let payloadData = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
              let payloadString = String(data: payloadData, encoding: .utf8),
              let payloadJson = try? JSONDecoder().decode(BreezeTokenPayload.self, from: payloadData) else {
                        print("error4")
            throw BreezeError.invalidToken
        }
        print("payloadJson: \(String(describing: payloadJson))")
        
        return payloadJson
    }
}

