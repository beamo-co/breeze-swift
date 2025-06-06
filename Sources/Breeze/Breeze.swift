//
//  BreezeSDK
//
//  Created by Andreas Sujono on 04.06.2025.
//

import Foundation
import StoreKit

@available(iOS 15, macOS 12, *)
@MainActor
public final class Breeze {
    // MARK: - Singleton
    public static let shared = Breeze()
    
    // MARK: - Properties
    internal var configuration: BreezeConfiguration?
    internal var isConfigured: Bool { configuration != nil }
    
    // MARK: - Transaction
    internal var pendingTransactions: [String: (transaction: BreezeTransaction, timestamp: Date)] = [:]
    internal var pendingTransactionTimer: Timer?

    
    internal let session: URLSession
    internal var baseURL: URL {
        switch configuration?.environment {
        case .production:
            return URL(string: BreezeConstants.API.productionBaseURL)!
        case .sandbox:
            return URL(string: BreezeConstants.API.productionBaseURL)!
        case .none:
            fatalError("Breeze SDK not configured")
        }
    }

    internal var purchaseCallback: ((BreezeTransaction) -> Void)?
    
    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = BreezeConstants.Network.requestTimeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Configuration
    public func configure(with configuration: BreezeConfiguration) {
        self.configuration = configuration
    }
    
    internal func createApiRequest(url: URL) -> URLRequest{
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(String(configuration?.userId ?? ""), forHTTPHeaderField: "x-user-unique-id")
        request.setValue(String(configuration?.userEmail ?? ""), forHTTPHeaderField: "x-user-email")
        request.setValue(String(configuration?.apiKey ?? ""), forHTTPHeaderField: "x-api-key")
        
        let credentials = "\(configuration?.apiKey ?? ""):"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Add timeout
        request.timeoutInterval = 30.0
        
        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            var queryItems = urlComponents.queryItems ?? []
            queryItems.append(URLQueryItem(name: "livemode", value: configuration?.environment == .production ? "true" : "false"))
            urlComponents.queryItems = queryItems
            request.url = urlComponents.url
        }
        return request
    }
}
