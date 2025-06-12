import Foundation
import StoreKit

extension Breeze {
    // MARK: - Purchase Flow
    
    @discardableResult
    public func purchase(_ product: BreezeProduct, onSuccess: @escaping (BreezeTransaction) -> Void) async throws -> BreezeTransaction? {
        guard isConfigured else {
            throw BreezeError.notConfigured
        }

        if(!product.existInBreeze){
            let transaction = try await skPurchase(product, onSuccess: onSuccess)
            if(transaction == nil){
                return nil
            }
            let breezeTransaction = BreezeTransaction(
                id: String(transaction!.id),
                productId: product.id,
                purchaseDate: transaction!.purchaseDate,
                skTransaction: transaction!,
                breezeTransactionId: UUID().uuidString,
                status: .purchased
            )
            return breezeTransaction
        }

        self.purchaseCallback = onSuccess
        
        let purchaseResponse: BreezePurchaseResponse
        do {
            let body: [String: Any] = [
                "productId": product.id,
                "redirectUrl": "\(configuration?.appScheme ?? "")\(BreezeConstants.URLScheme.paymentPath)" //ex: testapp://breeze-payment
            ]
            
            let purchaseApiRes: BreezeInitiatePurchaseApiResponse = try await postRequest(
                path: "/iap/client/purchase",
                body: body
            )
            purchaseResponse = purchaseApiRes.data
        } catch {
            throw error
        }

//        let purchaseResponse = BreezePurchaseResponse(
//            transactionId: UUID().uuidString,
//            breezeTransactionId: UUID().uuidString,
//            purchaseUrl: URL(string: "https://link.devdp.breeze.cash/link/plink_e38e9c7f5dee92ae?successReturnUrl=\(configuration!.appScheme)breeze-payment")!
//        )
        let breezeTransaction = BreezeTransaction(
            id: purchaseResponse.paymentPageId,
            productId: product.id,
            purchaseDate: Date(),
            breezeTransactionId: purchaseResponse.paymentPageId,
            status: .pending
        )
        var currentPendingTransactions = _getPendingTransactions()
        currentPendingTransactions[breezeTransaction.id] = (transaction: breezeTransaction, timestamp: Date())
        _setPendingTransactions(currentPendingTransactions)

        // Open purchase URL in browser
        #if os(iOS)
        await UIApplication.shared.open(URL(string: purchaseResponse.paymentPageUrl)!)
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

            let token = items.first(where: { $0.name == "signature" })?.value

//TODO must be inside pending transaction to prevent duplicate callback
//                let currentTransaction = pendingTransactions.first(where: { $0.key == transaction.id })
//                if(currentTransaction == nil){
//                    return
//                }
                var lastStatus = ""
                var lastPaymentPageID = ""
                var productId = ""
                var paymentAmount: String = ""

               do {
                   let tokenPayload = try validateJWT(token: String(token ?? ""))
                   lastStatus = tokenPayload.status
                   lastPaymentPageID = tokenPayload.paymentPageId
                   productId = tokenPayload.productId
                   paymentAmount = tokenPayload.paymentAmount
               } catch {
                print("error: \(error)")
                   return; //not valid token
               }

            let transaction = BreezeTransaction(
                id: lastPaymentPageID,
                productId: productId,
                purchaseDate: Date(),
                breezeTransactionId: lastPaymentPageID,
                status: .purchased //TODO: check for lastStatus
            )
            if let callback = purchaseCallback {

                print("call breeze purchase success callback", url, url.path)
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
        
        do {
            let transactionApiRes: BreezeGetTransactionApiResponse = try await getRequest(
                path: "/iap/client/entitlement/\(transactionId)"
            )
            let transactionResponse = transactionApiRes.data
            if(transactionResponse.status != .purchased){
                throw BreezeError.failedVerification
            }
            
            return BreezeTransaction(
                id: transactionResponse.id,
                productId: transactionResponse.productId,
                purchaseDate: transactionResponse.purchaseDate,
                originalPurchaseDate: transactionResponse.purchaseDate,
                expirationDate: transactionResponse.expirationDate,
                quantity: transactionResponse.quantity,
                breezeTransactionId: transactionResponse.id,
                status: transactionResponse.status
            )
        } catch{
            throw BreezeError.failedVerification
        }
    }
    
    public func finish(_ transaction: BreezeTransaction) {
        //remove from pending queue
        var currentPendingTransactions = _getPendingTransactions()
        currentPendingTransactions.removeValue(forKey: transaction.id)
        _setPendingTransactions(currentPendingTransactions)
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
    
    private func _getPendingTransactions() -> [String: (transaction: BreezeTransaction, timestamp: Date)]{
        return pendingTransactions
    }
    
    private func _setPendingTransactions(_ data: [String: (transaction: BreezeTransaction, timestamp: Date)]) {
        pendingTransactions = data
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
        
        var currentPendingTransactions = _getPendingTransactions()
        
        // Process each pending transaction
        for (transactionId, transactionData) in currentPendingTransactions {
            let timeElapsed = now.timeIntervalSince(transactionData.timestamp)
            
            // Check if transaction has timed out
            if timeElapsed >= BreezeConstants.Transaction.pendingTimeout {
                transactionsToRemove.append(transactionId)
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
            currentPendingTransactions.removeValue(forKey: transactionId)
        }
        
        // Stop timer if no more pending transactions
        if currentPendingTransactions.isEmpty {
            pendingTransactionTimer?.invalidate()
            pendingTransactionTimer = nil
        }
        
        _setPendingTransactions(currentPendingTransactions)
    }

    public func fromSkTransaction(skTransaction: StoreKit.Transaction) -> BreezeTransaction {
        return BreezeTransaction(
            id: String(skTransaction.id),
            productId: skTransaction.productID,
            purchaseDate: skTransaction.purchaseDate,
            skTransaction: skTransaction,
            breezeTransactionId: String(skTransaction.id),
            status: .pending //need to validate SK transaction directly
        )
    }

    public func fromSkTransactionV1(skTransaction: SKPaymentTransaction) -> BreezeTransaction {
        return BreezeTransaction(
            id: String(skTransaction.transactionIdentifier ?? ""),
            productId: skTransaction.payment.productIdentifier,
            purchaseDate: skTransaction.transactionDate ?? Date(),
            skTransactionV1: skTransaction,
            breezeTransactionId: String(skTransaction.transactionIdentifier ?? ""),
            status: skTransaction.transactionState == .purchased ? .purchased : .failed
        )
    }
}

@MainActor
extension BreezeProduct {
    ///  Convenience wrapper that delegates to a `Store` instance.
    @discardableResult
    public func purchase(using breeze: Breeze, onSuccess: @escaping (BreezeTransaction) -> Void) async throws -> BreezeTransaction? {
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
