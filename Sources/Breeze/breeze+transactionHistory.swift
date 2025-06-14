
import Foundation
import StoreKit

extension Breeze {
    // MARK: - Transaction History
    public func getEntitlements() async -> [BreezeTransaction]{
        var storeKitTransactions: [BreezeTransaction] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if(transaction.revocationDate != nil){
                    continue
                }
                storeKitTransactions.append(BreezeTransaction(
                    id: String(transaction.id),
                    productId: transaction.productID,
                    productType: parseSkProductType(transaction.productType),
                    purchaseDate: transaction.purchaseDate,
                    originalPurchaseDate: transaction.originalPurchaseDate,
                    expirationDate: transaction.expirationDate,
                    quantity: 1,
                    skTransaction: transaction,
                    breezeTransactionId: String(transaction.id),
                    status: .purchased
                ))
            case .unverified:
                continue
            }
        }
        
        var BreezeTransactions: [BreezeTransaction] = []
        do {
            let apiRes: BreezeGetActiveEntitlementsApiResponse = try await getRequest(
                path: "/iap/client/entitlements/current"
            )
            BreezeTransactions = apiRes.data.entitlements.map { transactionResponse in
                BreezeTransaction(
                    id: transactionResponse.paymentPageId,
                    productId: transactionResponse.productId,
                    productType: transactionResponse.productType,
                    purchaseDate: ISO8601DateFormatter().date(from: transactionResponse.purchaseDate) ?? Date(),
                    originalPurchaseDate: ISO8601DateFormatter().date(from: transactionResponse.purchaseDate) ?? Date(),
                    expirationDate: nil, // transactionResponse.expirationDate == nil ? nil : ISO8601DateFormatter().date(from: transactionResponse.expirationDate!) ?? Date(),
                    quantity: transactionResponse.quantity,
                    breezeTransactionId: transactionResponse.paymentPageId,
                    status: transactionResponse.status
                )
            }
        } catch {
            print("[Breeze] Failed to fetch Breeze entitlements: \(error)")
        }
        return storeKitTransactions + BreezeTransactions
    }
    
    public func getAllTransactions() async throws -> [BreezeTransaction]{
        guard isConfigured else {
            throw BreezeError.notConfigured
        }
        
        let apiRes: BreezeGetActiveEntitlementsApiResponse = try await getRequest(
            path: "/iap/client/entitlements"
        )
        return apiRes.data.entitlements.map { transactionResponse in
            BreezeTransaction(
                id: transactionResponse.paymentPageId,
                productId: transactionResponse.productId,
                productType: transactionResponse.productType,
                purchaseDate: ISO8601DateFormatter().date(from: transactionResponse.purchaseDate) ?? Date(),
                originalPurchaseDate: ISO8601DateFormatter().date(from: transactionResponse.purchaseDate) ?? Date(),
                expirationDate: nil, //transactionResponse.expirationDate == nil ? nil : ISO8601DateFormatter().date(from: transactionResponse.expirationDate!) ?? Date(),
                quantity: transactionResponse.quantity,
                breezeTransactionId: transactionResponse.paymentPageId,
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
        return apiRes.data.entitlements.map { transactionResponse in
            BreezeTransaction(
                id: transactionResponse.paymentPageId,
                productId: transactionResponse.productId,
                productType: transactionResponse.productType,
                purchaseDate: ISO8601DateFormatter().date(from: transactionResponse.purchaseDate) ?? Date(),
                originalPurchaseDate: ISO8601DateFormatter().date(from: transactionResponse.purchaseDate) ?? Date(),
                expirationDate: nil, //transactionResponse.expirationDate == nil ? nil : ISO8601DateFormatter().date(from: transactionResponse.expirationDate!) ?? Date(),
                quantity: transactionResponse.quantity,
                breezeTransactionId: transactionResponse.paymentPageId,
                status: transactionResponse.status
            )
        }
    }
}

@MainActor
extension BreezeTransaction {
    ///  Convenience wrapper that delegates to a `Store` instance.
    public func getEntitlements(using breeze: Breeze) async -> [BreezeTransaction] {
        return await breeze.getEntitlements()
    }
    
    public func getAllTransactions(using breeze: Breeze) async throws -> [BreezeTransaction] {
        return try await breeze.getAllTransactions()
    }
    
    public func getAllTransactionByProductId(using breeze: Breeze, productIds: [String]) async throws -> [BreezeTransaction] {
        return try await breeze.getAllTransactionByProductId(productIds: productIds)
    }
}
