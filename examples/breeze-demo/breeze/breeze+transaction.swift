public func purchase(_ product: BreezeProduct, onSuccess: @escaping (BreezeTransaction) -> Void) async throws -> BreezeTransaction {
    guard isConfigured else {
        throw BreezeError.notConfigured
    }

    self.purchaseCallback = onSuccess
    
    // ... existing code ...
    
    // Return initial transaction
    let transaction = BreezeTransaction(
        id: purchaseResponse.transactionId,
        productId: product.id,
        purchaseDate: Date(),
        breezeTransactionId: purchaseResponse.breezeTransactionId,
        status: .pending
    )
    
    // Add to pending transactions queue
    pendingTransactions[transaction.id] = (transaction: transaction, timestamp: Date())

     //must be inside pending transaction
    pendingTransactions.first(where: { $0.key == transaction.id })
    
    // Start pending transaction listener if not already running
    startPendingTransactionListener()
    
    return transaction
}

// MARK: - Pending Transaction Management

private func startPendingTransactionListener() {
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
        if timeElapsed >= pendingTransactionTimeout {
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
                transactionsToRemove.append(transactionId)
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

public func verifyUrl(_ url: URL) -> Void {
    // Accept both custom-scheme "myapp://payment" and
    // universal-link "https://pay.example.com/complete"
    guard ((url.host?.contains(BreezeConstants.URLScheme.paymentPath)) != nil) ||
          ((url.host?.contains(BreezeConstants.URLScheme.completePath)) != nil) else { return }
    
    // ... rest of the code ...
}

public func verifyTransaction(_ transactionId: String) async throws -> BreezeTransaction {
    guard isConfigured else {
        throw BreezeError.notConfigured
    }
    
    let url = baseURL.appendingPathComponent("transactions/\(transactionId)")
    var request = URLRequest(url: url)
    request.setValue(
        BreezeConstants.Network.bearerPrefix + configuration!.apiKey,
        forHTTPHeaderField: BreezeConstants.Network.authorizationHeader
    )
    
    let (data, response) = try await session.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          BreezeConstants.HTTPStatus.successRange.contains(httpResponse.statusCode) else {
        throw BreezeError.networkError
    }
    
    // ... rest of the code ...
}

// ... existing code ... 