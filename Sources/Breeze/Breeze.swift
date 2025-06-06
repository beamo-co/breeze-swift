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
        request.setValue("x-user-unique-id", forHTTPHeaderField: String(configuration?.userId ?? ""))
        request.setValue("x-user-email", forHTTPHeaderField: String(configuration?.userEmail ?? ""))
        request.setValue("x-api-key", forHTTPHeaderField: String(configuration?.apiKey ?? ""))
        request.setValue("Authentication", forHTTPHeaderField: "Basic \(configuration?.apiKey ?? ""):") //testing using Basic auth

        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            var queryItems = urlComponents.queryItems ?? []
            queryItems.append(URLQueryItem(name: "livemode", value: configuration?.environment == .production ? "true" : "false"))
            urlComponents.queryItems = queryItems
            request.url = urlComponents.url
        }
        return request
    }
}
