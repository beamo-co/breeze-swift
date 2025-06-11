
import Foundation
import StoreKit

extension Breeze {
    // MARK: - Transaction History
    public func getEntitlements() async throws -> [BreezeTransaction]{
        guard isConfigured else {
            throw BreezeError.notConfigured
        }
        
        let apiRes: BreezeGetActiveEntitlementsApiResponse = try await getRequest(
            path: "/iap/client/entitlements/current"
        )
        return apiRes.data.map { transactionResponse in
            BreezeTransaction(
                id: transactionResponse.id,
                productId: transactionResponse.productId,
                purchaseDate: transactionResponse.purchaseDate,
                originalPurchaseDate: transactionResponse.purchaseDate,
                expirationDate: transactionResponse.expirationDate,
                quantity: transactionResponse.quantity,
                breezeTransactionId: transactionResponse.id,
                status: transactionResponse.status
            )
        }
    }
    
    public func getAllTransactions() async throws -> [BreezeTransaction]{
        guard isConfigured else {
            throw BreezeError.notConfigured
        }
        
        let apiRes: BreezeGetActiveEntitlementsApiResponse = try await getRequest(
            path: "/iap/client/entitlements"
        )
        return apiRes.data.map { transactionResponse in
            BreezeTransaction(
                id: transactionResponse.id,
                productId: transactionResponse.productId,
                purchaseDate: transactionResponse.purchaseDate,
                originalPurchaseDate: transactionResponse.purchaseDate,
                expirationDate: transactionResponse.expirationDate,
                quantity: transactionResponse.quantity,
                breezeTransactionId: transactionResponse.id,
                status: transactionResponse.status
            )
        }
    }
    
    public func getAllTransactionByProductId(productIds: [String]) async throws -> [BreezeTransaction]{
        guard isConfigured else {
            throw BreezeError.notConfigured
        }
        
        let apiRes: BreezeGetActiveEntitlementsApiResponse = try await getRequest(
            path: "/iap/client/entitlements",
            queryParams: [
                "productIds": productIds.joined(separator: ",")
            ]
        )
        return apiRes.data.map { transactionResponse in
            BreezeTransaction(
                id: transactionResponse.id,
                productId: transactionResponse.productId,
                purchaseDate: transactionResponse.purchaseDate,
                originalPurchaseDate: transactionResponse.purchaseDate,
                expirationDate: transactionResponse.expirationDate,
                quantity: transactionResponse.quantity,
                breezeTransactionId: transactionResponse.id,
                status: transactionResponse.status
            )
        }
    }
}

@MainActor
extension BreezeTransaction {
    ///  Convenience wrapper that delegates to a `Store` instance.
    public func getEntitlements(using breeze: Breeze) async throws -> [BreezeTransaction] {
        return try await breeze.getEntitlements()
    }
    
    public func getAllTransactions(using breeze: Breeze) async throws -> [BreezeTransaction] {
        return try await breeze.getAllTransactions()
    }
    
    public func getAllTransactionByProductId(using breeze: Breeze, productIds: [String]) async throws -> [BreezeTransaction] {
        return try await breeze.getAllTransactionByProductId(productIds: productIds)
    }
}
