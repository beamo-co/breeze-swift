import Foundation
import StoreKit

public struct BreezeProduct: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let displayPrice: String
    public let currencyCode: String
    public let skProduct: StoreKit.Product? // Underlying StoreKit product if available
    
    // Additional Breeze-specific properties
    public let breezeProductId: String
    public let purchaseUrl: URL?
    public let type: ProductType
    public let existInBreeze: Bool
    
    public enum ProductType: String, Codable, Sendable {
        case consumable = "CONSUMABLE"
        case nonConsumable = "NON_CONSUMABLE"
        case autoRenewable = "AUTO_RENEWABLE"
        case nonRenewable = "NON_RENEWABLE"
    }

    public init(
        id: String,
        displayName: String,
        description: String,
        price: Decimal,
        displayPrice: String,
        currencyCode: String,
        storeProduct: StoreKit.Product? = nil,
        breezeProductId: String,
        purchaseUrl: URL? = nil,
        type: ProductType,
        existInBreeze: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.price = price
        self.displayPrice = displayPrice
        self.currencyCode = currencyCode
        self.skProduct = storeProduct
        self.breezeProductId = breezeProductId
        self.purchaseUrl = purchaseUrl
        self.type = type
        self.existInBreeze = existInBreeze
    }
}

public struct BreezeTransaction: Identifiable, Sendable {
    public let id: String
    public let productId: String
    public let productType: BreezeProduct.ProductType
    public let purchaseDate: Date
    public let originalPurchaseDate: Date?
    public let expirationDate: Date?
    public let quantity: Int
    public let skTransaction: StoreKit.Transaction? // Underlying StoreKit transaction if available
    public let skTransactionV1: SKPaymentTransaction? // Underlying StoreKit transaction if available
    
    // Additional Breeze-specific properties
    public let breezeTransactionId: String
    public let status: TransactionStatus
    public let receipt: String?
    
    public enum TransactionStatus: String, Codable, Sendable {
        case purchased = "purchased"
        case pending = "pending"
        case failed = "failed"
        case expired = "expired"
        case refunded = "refunded"
    }
    
    public init(
        id: String,
        productId: String,
        productType: BreezeProduct.ProductType,
        purchaseDate: Date,
        originalPurchaseDate: Date? = nil,
        expirationDate: Date? = nil,
        quantity: Int = 1,
        skTransaction: StoreKit.Transaction? = nil,
        skTransactionV1: SKPaymentTransaction? = nil,
        breezeTransactionId: String,
        status: TransactionStatus,
        receipt: String? = nil
    ) {
        self.id = id
        self.productId = productId
        self.productType = productType
        self.purchaseDate = purchaseDate
        self.originalPurchaseDate = originalPurchaseDate
        self.expirationDate = expirationDate
        self.quantity = quantity
        self.skTransaction = skTransaction
        self.skTransactionV1 = skTransactionV1
        self.breezeTransactionId = breezeTransactionId
        self.status = status
        self.receipt = receipt
    }
}

// Configuration options for Breeze SDK
public struct BreezeConfiguration {
    public let apiKey: String
    public let appScheme: String
    public let userId: String?
    public let userEmail: String?
    public let environment: Environment?
    
    public enum Environment {
        case production
        case sandbox
    }
    
    @MainActor
    public init(
        apiKey: String,
        appScheme: String,
        userId: String? = nil,
        userEmail: String? = nil,
        environment: Environment? = .production
    ) {
        var chosenUserId = userId
        #if os(iOS)
        if(chosenUserId == nil){
            chosenUserId = UIDevice.current.identifierForVendor?.uuidString //default to device uuid
        }
        #endif
        self.apiKey = apiKey
        self.userId = userId
        self.userEmail = userEmail
        self.environment = environment
        self.appScheme = appScheme
    }
}


// MARK: - Supporting Types
 extension Breeze {
    enum BreezeError: Error {
        case notConfigured
        case networkError
        case invalidResponse
        case purchaseFailed
        case failedVerification
        case invalidToken
        case invalidURL
        case decodingError
    }
    
    internal struct BreezeBackendProduct: Codable {
        let id: String
        let displayName: String
        let description: String
        let price: String
        let displayPrice: String
        let type: BreezeProduct.ProductType
    }
     
    internal struct BreezePurchaseResponse: Codable {
        let paymentPageUrl: String
        let paymentPageId: String
    }
    
    internal struct BreezeTransactionResponse: Codable {
        let id: String
        let productId: String
        let productType: BreezeProduct.ProductType
        let purchaseDate: String
        // let expirationDate: String?
        let quantity: Int
        let status: BreezeTransaction.TransactionStatus
        let paymentPageId: String
    }
     
     //API Reponse
     internal struct BreezeGetProductsApiResponse: Codable {
         let status: String
         let data: Data
         
         struct Data: Codable {
             let products: [BreezeBackendProduct]
         }
     }
     
     internal struct BreezeInitiatePurchaseApiResponse: Codable {
         let status: String
         let data: BreezePurchaseResponse
     }
     
     internal struct BreezeGetActiveEntitlementsApiResponse: Codable {
         let status: String
         let data: Data

         struct Data: Codable {
             let entitlements: [BreezeTransactionResponse]
         }
     }

     public struct BreezeTokenPayload: Codable {
       	let successPaymentId: String // pay_X
       	let paymentPageId: String // payment_page_x
       	let paymentAmount: String // "100.55" major unit
       	let productId: String // client product ID
        let productType: BreezeProduct.ProductType
       	let status: String // PAID
     }
}
