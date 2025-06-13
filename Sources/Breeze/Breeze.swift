//
//  BreezeSDK
//
//  Created by Andreas on 04.06.2025.
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

        // Add locale and country code
        let locale = Locale.current
        let countryCode = locale.regionCode ?? "US"
        request.setValue(countryCode, forHTTPHeaderField: "x-country-code")
        request.setValue(locale.identifier, forHTTPHeaderField: "x-locale")
        // print("locale: \(locale.identifier)")
        // print("countryCode: \(countryCode)")
        request.timeoutInterval = 30.0
        
        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            var queryItems = urlComponents.queryItems ?? []
            queryItems.append(URLQueryItem(name: "livemode", value: configuration?.environment == .production ? "true" : "false"))
            urlComponents.queryItems = queryItems
            request.url = urlComponents.url
        }
        return request
    }
    
    internal func getRequest<T: Codable>(path: String, queryParams: [String: String]? = nil) async throws -> T {
        var url = baseURL.appendingPathComponent(path)
        
        // Handle URL components and query parameters
        if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            var queryItems = urlComponents.queryItems ?? []
            if let queryParams = queryParams {
                for (key, value) in queryParams {
                    queryItems.append(URLQueryItem(name: key, value: value))
                }
            }
            
            urlComponents.queryItems = queryItems
            guard let finalURL = urlComponents.url else {
                throw BreezeError.invalidURL
            }
            url = finalURL
        }
        
        // Create the request
        var request = createApiRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BreezeError.networkError
        }

         if let httpResponse = response as? HTTPURLResponse {            
            if httpResponse.statusCode == 200 {
                // // Success - parse the response data
                // if let responseString = String(data: data, encoding: .utf8) {
                //     print("Response: \(responseString)")
                // }
                
                // If expecting JSON response, parse it:
                // let jsonResponse = try JSONSerialization.jsonObject(with: data)
                // print("JSON Response: \(jsonResponse)")
            } else {
                // Handle HTTP error
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[Breeze] HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            }
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
        } catch {
            throw BreezeError.decodingError
        }
    }
    
    internal func postRequest<T: Codable>(path: String, body: [String: Any]? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
                
        // Create the request
        var request = createApiRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body as Any)

        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {            
            if httpResponse.statusCode == 200 {
                // Success - parse the response data
                // if let responseString = String(data: data, encoding: .utf8) {
                //     print("Response: \(responseString)")
                // }
                
                // If expecting JSON response, parse it:
                // let jsonResponse = try JSONSerialization.jsonObject(with: data)
                // print("JSON Response: \(jsonResponse)")
            } else {
                // Handle HTTP error
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[Breeze] HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print(response)
            throw BreezeError.networkError
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
        } catch {
            throw BreezeError.decodingError
        }
    }
}
