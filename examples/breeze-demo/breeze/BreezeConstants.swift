import Foundation

enum BreezeConstants {
    // MARK: - API URLs
    enum API {
        static let productionBaseURL = "https://api.breeze.cash/v1"
        static let sandboxBaseURL = "https://api.qa.breeze.com/v1"
    }
    
    // MARK: - Transaction
    enum Transaction {
        static let pendingTimeout: TimeInterval = 600 // 10 minutes in seconds
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