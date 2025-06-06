import Foundation
import StoreKit

extension Breeze {
    // MARK: - Purchase Flow
    
    @discardableResult
    public func purchase(_ product: BreezeProduct, onSuccess: @escaping (BreezeTransaction) -> Void) async throws -> BreezeTransaction {
        guard isConfigured else {
            throw BreezeError.notConfigured
        }

        self.purchaseCallback = onSuccess
        
         // Create purchase intent on backend
         let url = baseURL.appendingPathComponent("payment_pages")
         var request =  createApiRequest(url: url)
         let body: [String: Any] = [
            "lineItems":[
                [
                    "product":"prod_a3f5e45fba70627e",
                    "quantity":2
                ]
            ],
            "clientReferenceId":"testoerer13132"
         ]
         request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
         let (data, response) = try await session.data(for: request)
        
         guard let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) else {
             throw BreezeError.networkError
         }
        
         let purchaseResponse = try JSONDecoder().decode(BreezePurchaseResponseTest.self, from: data)

//        let purchaseResponse = BreezePurchaseResponse(
//            transactionId: UUID().uuidString,
//            breezeTransactionId: UUID().uuidString,
//            purchaseUrl: URL(string: "https://link.devdp.breeze.cash/link/plink_e38e9c7f5dee92ae?successReturnUrl=\(configuration!.appScheme)breeze-payment")!
//        )
        let breezeTransaction = BreezeTransaction(
            id: purchaseResponse.data.id,
            productId: product.id,
            purchaseDate: Date(),
            breezeTransactionId: purchaseResponse.data.id,
            status: .pending
        )
        pendingTransactions[breezeTransaction.id] = (transaction: breezeTransaction, timestamp: Date())

        // Open purchase URL in browser
        #if os(iOS)
        await UIApplication.shared.open(purchaseResponse.data.url)
        #endif
        _startPendingTransactionListener()
        
        // Return initial transaction
        return breezeTransaction
    }
    
    public func setPurchaseCallback(onSuccess: @escaping (BreezeTransaction) -> Void) {
        self.purchaseCallback = onSuccess
    }
    
    public func skPurchase(_ product: BreezeProduct, onSuccess: ((BreezeTransaction) -> Void)? = nil) async throws -> StoreKit.Transaction? {
        if(product.skProduct == nil){
            throw BreezeError.failedVerification
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
        guard
            let host = url.host,
            host.contains(BreezeConstants.URLScheme.paymentPath)
        else { return }
        
        print("Breeze url callback called: ", String(url.host!))
        
        //URL: testapp://breeze-payment
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {

            let lastStatus = items.first(where: { $0.name == "paymentStatus" })?.value
            let lastPaymentID = items.first(where: { $0.name == "paymentId" })?.value

            let transaction = BreezeTransaction(
                id: UUID().uuidString,
                productId: "consumable.fuel.octane87",
                purchaseDate: Date(),
                breezeTransactionId: UUID().uuidString,
                status: .purchased
            )
            if let callback = purchaseCallback {
//                //must be inside pending transaction to prevent duplicate callback
//                let currentTransaction = pendingTransactions.first(where: { $0.key == transaction.id })
//                if(currentTransaction == nil){
//                    return
//                }
                print("call callback", url, url.path)
                callback(transaction)
                // Clear the callback after use
                purchaseCallback = nil
            }
            return
        }
        
        return
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
    
    public func finish(_ transaction: BreezeTransaction) {
        //remove from pending queue
        pendingTransactions.removeValue(forKey: transaction.id)
    }
    
    private func _checkSkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw BreezeError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    private func _startPendingTransactionListener() {
        // Stop existing timer if running
        pendingTransactionTimer?.invalidate()
        
        // Create new timer that fires every 30 seconds
        pendingTransactionTimer = Timer.scheduledTimer(
            withTimeInterval: BreezeConstants.Transaction.verificationInterval,
            repeats: true
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.processPendingTransactions()
            }
        }
    }
    
    
    private func processPendingTransactions() async {
        let now = Date()
        var transactionsToRemove: [String] = []
        
        // Process each pending transaction
        for (transactionId, transactionData) in pendingTransactions {
            let timeElapsed = now.timeIntervalSince(transactionData.timestamp)
            
            // Check if transaction has timed out
            if timeElapsed >= BreezeConstants.Transaction.pendingTimeout {
                transactionsToRemove.append(transactionId)
                continue
            }
            
            do {
                // Verify transaction with backend
                let verifiedTransaction = try await verifyTransaction(transactionId)
                
                // If transaction is paid, call success callback and remove from queue
                if verifiedTransaction.status == .purchased {
                    if let callback = purchaseCallback {
                        callback(verifiedTransaction)
                    }
                }
            } catch {
                // Log error but keep transaction in queue
                print("Failed to verify transaction \(transactionId): \(error)")
            }
        }
        
        // Remove processed transactions from queue
        for transactionId in transactionsToRemove {
            pendingTransactions.removeValue(forKey: transactionId)
        }
        
        // Stop timer if no more pending transactions
        if pendingTransactions.isEmpty {
            pendingTransactionTimer?.invalidate()
            pendingTransactionTimer = nil
        }
    }
}

@MainActor
extension BreezeProduct {
    ///  Convenience wrapper that delegates to a `Store` instance.
    @discardableResult
    public func purchase(using breeze: Breeze, onSuccess: @escaping (BreezeTransaction) -> Void) async throws -> BreezeTransaction {
        return try await breeze.purchase(self, onSuccess: onSuccess)
    }
    
    /// Convenience wrapper that delegates to a `Store` instance.
    public func skPurchase(using breeze: Breeze) async throws -> StoreKit.Transaction?  {
        return try await breeze.skPurchase(self)
    }
}


@MainActor
extension BreezeTransaction {
    ///  Convenience wrapper that delegates to a `Store` instance.
    public func finish(using breeze: Breeze) {
        return breeze.finish(self)
    }
}
