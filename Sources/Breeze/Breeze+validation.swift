import Foundation
import CryptoKit

extension P256.Signing.PublicKey {
    init(pem pemString: String) throws {
        let lines = pemString
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        guard let der = Data(base64Encoded: lines.joined()) else {
            throw JWTError.badBase64
        }
        try self.init(derRepresentation: der)
    }
}


enum JWTError: Error {
    case malformedToken, badBase64, wrongAlgorithm, badSignature
}

struct JWTES256Validator {
    let publicKey: P256.Signing.PublicKey
    
    /// On success returns the **payload JSON object**; otherwise throws.
    func verifyAndDecode(token: String) throws -> [String: Any] {
        // 1. Split header.payload.signature
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw JWTError.malformedToken }
        let headerB64 = String(parts[0]), payloadB64 = String(parts[1]), sigB64 = String(parts[2])
        
        // 2. Check alg == ES256
        guard
            let headerData = Data(base64URLEncoded: headerB64),
            let headerJSON = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
            (headerJSON["alg"] as? String) == "ES256"
        else { throw JWTError.wrongAlgorithm }
        
        // 3. Decode signature (r‖s)
        guard
            let sigRaw = Data(base64URLEncoded: sigB64),
            sigRaw.count == 64
        else { throw JWTError.badSignature }
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: sigRaw)
        
        // 4. Hash header.payload (as-is, still Base64URL)
        let signingInput = parts[0] + "." + parts[1]
        let digest = SHA256.hash(data: Data(signingInput.utf8))
        
        // 5. Verify signature
        guard publicKey.isValidSignature(signature, for: digest) else {
            throw JWTError.badSignature
        }
        
        // 6. Return decoded payload JSON
        guard
            let payloadData = Data(base64URLEncoded: payloadB64),
            let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { throw JWTError.badBase64 }
        
        return payloadJSON
    }
}


extension Data {
    /// Initialize from Base64 URL (no padding, URL-safe charset)
    init?(base64URLEncoded input: String) {
        var fixed = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to 4-char multiple
        while fixed.count % 4 != 0 { fixed.append("=") }
        guard let data = Data(base64Encoded: fixed) else { return nil }
        self = data
    }
}



public func validateJWT(token: String) throws -> Breeze.BreezeTokenPayload {
    let keyFromPem = try P256.Signing.PublicKey(pem: BreezeConstants.API.apiPublicKey)
    let validator = JWTES256Validator(publicKey: keyFromPem)
    let payload = try validator.verifyAndDecode(token: token)
    
    return Breeze.BreezeTokenPayload(
        successPaymentId: payload["successPaymentId"] as? String ?? "",
        paymentPageId: payload["paymentPageId"] as? String ?? "",
        paymentAmount: payload["paymentAmount"] as? String ?? "",
        productId: payload["productId"] as? String ?? "",
        status: payload["status"] as? String ?? ""
    )
}