import Foundation
import StoreKit

extension Breeze {
    // MARK: - Purchase Flow
    public func purchase(_ product: BreezeProduct, onSuccess: @escaping (BreezeTransaction) -> Void) async throws -> BreezeTransaction {
        guard isConfigured else {
            throw BreezeError.notConfigured
        }

        self.purchaseCallback = onSuccess
        
        // // Create purchase intent on backend
        // let url = baseURL.appendingPathComponent("purchases")
        // var request = URLRequest(url: url)
        // request.httpMethod = "POST"
        // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // request.setValue("Bearer \(configuration!.apiKey)", forHTTPHeaderField: "Authorization")
        
        // let body: [String: Any] = [
        //     "product_id": product.breezeProductId,
        //     "user_id": configuration!.userId as Any,
        //     "user_email": configuration!.userEmail as Any
        // ]
        // request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // let (data, response) = try await session.data(for: request)
        
        // guard let httpResponse = response as? HTTPURLResponse,
        //       (200...299).contains(httpResponse.statusCode) else {
        //     throw BreezeError.networkError
        // }
        
        // let purchaseResponse = try JSONDecoder().decode(BreezePurchaseResponse.self, from: data)

        let purchaseResponse = BreezePurchaseResponse(
            transactionId: UUID().uuidString,
            breezeTransactionId: UUID().uuidString,
            purchaseUrl: URL(string: "https://link.devdp.breeze.cash/link/plink_e38e9c7f5dee92ae?successReturnUrl=\(configuration!.appScheme)breeze-payment")!
        )
        
        // Open purchase URL in browser
        await UIApplication.shared.open(purchaseResponse.purchaseUrl)
        
        // Return initial transaction
        return BreezeTransaction(
            id: purchaseResponse.transactionId,
            productId: product.id,
            purchaseDate: Date(),
            breezeTransactionId: purchaseResponse.breezeTransactionId,
            status: .pending
        )
    }
    
    public func skPurchase(_ product: BreezeProduct, onSuccess: ((BreezeTransaction) -> Void)? = nil) async throws -> StoreKit.Transaction? {
        if(product.skProduct == nil){
            throw StoreError.failedVerification
        }
            
        // Begin purchasing the `Product` the user selects.
        let result = try await product.skProduct?.purchase()

        switch result {
        case .success(let verification):
            // Check whether the transaction is verified. If it isn't,
            // this function rethrows the verification error.
            let transaction = try _checkSkVerified(verification)
            
            // Always finish a transaction.
            await transaction.finish()
            
            if let onSuccess = onSuccess {
                let breezeTransaction = BreezeTransaction(
                    id: String(transaction.id),
                    productId: product.id,
                    purchaseDate: transaction.purchaseDate,
                    skTransaction: transaction,
                    breezeTransactionId: UUID().uuidString,
                    status: .purchased
                )
                onSuccess(breezeTransaction)
            }

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    public func verifyUrl(_ url: URL) -> Void {
        // Accept both custom-scheme “myapp://payment” and
        // universal-link “https://pay.example.com/complete”
        guard ((url.host?.contains("breeze-payment")) != nil) || ((url.host?.contains("complete")) != nil) else { return }

        //URL: testapp-andreas://breeze-payment
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {

            let lastStatus = items.first(where: { $0.name == "paymentStatus" })?.value
            let lastPaymentID = items.first(where: { $0.name == "paymentId" })?.value

            let transaction = BreezeTransaction(
                id: UUID().uuidString,
                productId: UUID().uuidString,
                purchaseDate: Date(),
                breezeTransactionId: UUID().uuidString,
                status: .purchased
            )
            if let callback = purchaseCallback {
                print("call callback", url, url.path)
                callback(transaction)
                // Clear the callback after use
                purchaseCallback = nil
            }
            return
        }
        
        
        let transaction = BreezeTransaction(
            id: UUID().uuidString,
            productId: UUID().uuidString,
            purchaseDate: Date(),
            breezeTransactionId: UUID().uuidString,
            status: .purchased
        )
        if let callback = purchaseCallback {
            callback(transaction)
            // Clear the callback after use
            purchaseCallback = nil
        }
        return
    }
    
    private func _checkSkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    // MARK: - Transaction Verification
    public func verifyTransaction(_ transactionId: String) async throws -> BreezeTransaction {
        guard isConfigured else {
            throw BreezeError.notConfigured
        }
        
        let url = baseURL.appendingPathComponent("transactions/\(transactionId)")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration!.apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BreezeError.networkError
        }
        
        let transactionResponse = try JSONDecoder().decode(BreezeTransactionResponse.self, from: data)
        
        return BreezeTransaction(
            id: transactionResponse.id,
            productId: transactionResponse.productId,
            purchaseDate: transactionResponse.purchaseDate,
            originalPurchaseDate: transactionResponse.originalPurchaseDate,
            expirationDate: transactionResponse.expirationDate,
            quantity: transactionResponse.quantity,
            breezeTransactionId: transactionResponse.breezeTransactionId,
            status: transactionResponse.status,
            receipt: transactionResponse.receipt
        )
    }
}
