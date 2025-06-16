internal var baseURL: URL {
    switch configuration?.environment {
    case .production:
        return URL(string: BreezeConstants.API.productionBaseURL)!
    case .sandbox:
        return URL(string: BreezeConstants.API.sandboxBaseURL)!
    case .none:
        fatalError("Breeze SDK not configured")
    }
}

internal var purchaseCallback: ((BreezeTransaction) -> Void)?

// Pending transactions queue
private var pendingTransactions: [String: (transaction: BreezeTransaction, timestamp: Date)] = [:]
private var pendingTransactionTimer: Timer?
private let pendingTransactionTimeout = BreezeConstants.Transaction.pendingTimeout

// MARK: - Initialization
private init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = BreezeConstants.Network.requestTimeout
    self.session = URLSession(configuration: config)
} 