import Foundation

enum BreezeConstants {
    // MARK: - API URLs
    enum API {
        static let productionBaseURL = "https://api.qa.breeze.cash"
        static let sandboxBaseURL = "https://api.qa.breeze.cash"
        static let apiPublicKey = """
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWTpKi/3N5MB8rSgDh4cXRZaSwJjl
        LyP0bdmoqOjab39Be0pCryBm85wa8b9ys5RfUPA+mQKYwg1e1PjRVmVczw==
        -----END PUBLIC KEY-----
"""
    }
    
    // MARK: - Transaction
    enum Transaction {
        static let pendingTimeout: TimeInterval = 300 // 5 minutes in seconds
        static let verificationInterval: TimeInterval = 30 // Check every 30 seconds
    }
    
    // MARK: - Network
    enum Network {
        static let requestTimeout: TimeInterval = 30
        static let contentType = "application/json"
        static let authorizationHeader = "Authorization"
        static let bearerPrefix = "Bearer "
    }
    
    // MARK: - URL Schemes
    enum URLScheme {
        static let paymentPath = "breeze-payment"
        static let completePath = "complete"
    }
    
    // MARK: - HTTP Status Codes
    enum HTTPStatus {
        static let successRange = 200...299
    }
}
