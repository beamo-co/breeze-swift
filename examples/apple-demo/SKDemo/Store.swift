/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The class responsible for requesting products from the App Store and starting purchases.
*/

import Foundation
import StoreKit
import Breeze

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

// Define the app's subscription entitlements by level of service, with the highest level of service first.
// The numerical-level value matches the subscription's level that you configure in
// the StoreKit configuration file or App Store Connect.
public enum ServiceEntitlement: Int, Comparable {
    case notEntitled = 0
    
    case pro = 1
    case premium = 2
    case standard = 3
    
    init?(for product: Product) {
        // The product must be a subscription to have service entitlements.
        guard let subscription = product.subscription else {
            return nil
        }
        if #available(iOS 16.4, *) {
            self.init(rawValue: subscription.groupLevel)
        } else {
            switch product.id {
            case "subscription.standard":
                self = .standard
            case "subscription.premium":
                self = .premium
            case "subscription.pro":
                self = .pro
            default:
                self = .notEntitled
            }
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        // Subscription-group levels are in descending order.
        return lhs.rawValue > rhs.rawValue
    }
}

class Store: ObservableObject {

    @Published private(set) var cars: [BreezeProduct]
    @Published private(set) var fuel: [BreezeProduct]
    @Published private(set) var subscriptions: [Product]
    @Published private(set) var nonRenewables: [BreezeProduct]
    
    @Published private(set) var purchasedCars: [BreezeProduct] = []
    @Published private(set) var purchasedNonRenewableSubscriptions: [BreezeProduct] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: Product.SubscriptionInfo.Status?
    
    var updateListenerTask: Task<Void, Error>? = nil

    private let productIdToEmoji: [String: String]

    init() {
        productIdToEmoji = Store.loadProductIdToEmojiData()

        // Initialize empty products, then do a product request asynchronously to fill them in.
        cars = []
        fuel = []
        subscriptions = []
        nonRenewables = []

        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            // Listen for Breeze Listener
            await Breeze.shared.setPurchaseCallback(onSuccess: {breezeTransaction in
                Task {
                    try await self.onPurchaseSuccessful(breezeTransaction)
                }
            })
            
            // During store initialization, request products from the App Store.
            await requestProducts()

            // Deliver products that the customer purchases.
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }
    
    static func loadProductIdToEmojiData() -> [String: String] {
        guard let path = Bundle.main.path(forResource: "Products", ofType: "plist"),
              let plist = FileManager.default.contents(atPath: path),
              let data = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: String] else {
            return [:]
        }
        return data
    }

    func listenForTransactions() -> Task<Void, Error> {
        //listen for Storekit Listener
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Deliver products to the user.
                    await self.updateCustomerProductStatus()

                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification.")
                }
            }
        }
    }

    @MainActor
    func requestProducts() async {
        do {
            // Request products from the App Store using the identifiers that the `Products.plist` file defines.
            let storeProducts = try await Breeze.shared.products(productIds: Array(productIdToEmoji.keys))

            var newCars: [BreezeProduct] = []
            var newSubscriptions: [Product] = []
            var newNonRenewables: [BreezeProduct] = []
            var newFuel: [BreezeProduct] = []

            // Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    newFuel.append(product)
                case .nonConsumable:
                    newCars.append(product)
                case .autoRenewable:
                    if let skProduct = product.skProduct {
                        newSubscriptions.append(skProduct)
                    }
                case .nonRenewable:
                    newNonRenewables.append(product)
//                default:
//                    // Ignore this product.
//                    print("Unknown product.")
                }
            }

            // Sort each product category by price, lowest to highest, to update the store.
            cars = sortByPrice(newCars)
            subscriptions = newSubscriptions
            nonRenewables = sortByPrice(newNonRenewables)
            fuel = sortByPrice(newFuel)
        } catch {
            print("Failed product request from the App Store server. \(error)")
        }
    }

    func purchase(_ product: BreezeProduct,  onSuccess: (() -> Void)? = nil) async throws {
        // using breeze
        return try await purchaseWeb(product, onSuccess: onSuccess)

        // switch result {
        // case .success(let verification):
        //     // Check whether the transaction is verified. If it isn't,
        //     // this function rethrows the verification error.
        //     let transaction = try checkVerified(verification)

        //     // The transaction is verified. Deliver content to the user.
        //     await updateCustomerProductStatus()

        //     // Always finish a transaction.
        //     await transaction.finish()

        //     return transaction
        // case .userCancelled, .pending:
        //     return nil
        // default:
        //     return nil
        // }
    }
    
    
    func purchaseWeb(_ breezeProduct: BreezeProduct, onSuccess: (() -> Void)? = nil) async throws {
        try await breezeProduct.purchase(using: Breeze.shared, onSuccess: { transaction in
            Task {
                try await self.onPurchaseSuccessful(transaction)
            }
            onSuccess?()
        })
    }
    
    func onPurchaseSuccessful(_ transaction: BreezeTransaction) async throws {
        let chosenConsumableProducts = fuel.filter { $0.id == transaction.productId }
        let chosenNonConsumableProducts = cars.filter { $0.id == transaction.productId }
        if(chosenConsumableProducts.count > 0){ 
            //user bought consumable product, give balance here
            let availableFuels = UserDefaults.standard.integer(forKey: transaction.productId)
            UserDefaults.standard.set(availableFuels + 1, forKey: transaction.productId)
        } else if(chosenNonConsumableProducts.count > 0){
            //user bought non consumable product, give it to user
            await updateCustomerProductStatus()
        }
        
        // using storekit tx
        if(transaction.skTransaction != nil){
            // Always finish a transaction.
            await transaction.skTransaction!.finish()
            return
        } else {
            await Breeze.shared.finish(transaction)
        }
    }

    func isPurchased(_ product: BreezeProduct) async throws -> Bool {
        // Determine whether the user purchases a given product.
        switch product.type {
        case .nonRenewable:
            return purchasedNonRenewableSubscriptions.contains { $0.id == product.id }
        case .nonConsumable:
            return purchasedCars.contains { $0.id == product.id }
        case .autoRenewable:
            return purchasedSubscriptions.contains { $0.id == product.id }
        default:
            return false
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
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

    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedCars: [BreezeProduct] = []
        var purchasedSubscriptions: [Product] = []
        var purchasedNonRenewableSubscriptions: [BreezeProduct] = []
        
        let allEntitlements = await Breeze.shared.getEntitlements()
        
        // Iterate through all of the user's purchased products.
        for result in allEntitlements {
            let transaction = result
            // Check the `productType` of the transaction and get the corresponding product from the store.
            switch transaction.productType {
            case .nonConsumable:
                if let car = cars.first(where: { $0.id == result.productId }) {
                    let addedPurchasedCars = purchasedCars.first { $0.id == car.id }
                    if(addedPurchasedCars == nil){
                        purchasedCars.append(car)
                    }
                }
            case .nonRenewable:
                if let nonRenewable = nonRenewables.first(where: { $0.id == transaction.productId }),
                   transaction.productId == "nonRenewing.standard" {
                    // Non-renewing subscriptions have no inherent expiration date, so `Transaction.currentEntitlements`
                    // always contains them after the user purchases them.
                    // This app defines this non-renewing subscription's expiration date to be one year after purchase.
                    // If the current date is within one year of the `purchaseDate`, the user is still entitled to this
                    // product.
                    let currentDate = Date()
                    let expirationDate = Calendar(identifier: .gregorian).date(byAdding: DateComponents(year: 1),
                                                               to: transaction.purchaseDate)!

                    if currentDate < expirationDate {
                        purchasedNonRenewableSubscriptions.append(nonRenewable)
                    }
                }
            case .autoRenewable:
                if let subscription = subscriptions.first(where: { $0.id == transaction.productId }) {
                    purchasedSubscriptions.append(subscription)
                }
            default:
                break
            }
        }

        // Update the store information with the purchased products.
        self.purchasedCars = purchasedCars
        self.purchasedNonRenewableSubscriptions = purchasedNonRenewableSubscriptions

        // Update the store information with auto-renewable subscription products.
        self.purchasedSubscriptions = purchasedSubscriptions
    }

    func emoji(for productId: String) -> String {
        return productIdToEmoji[productId]!
    }

    func sortByPrice(_ products: [BreezeProduct]) -> [BreezeProduct] {
        products.sorted(by: { return $0.price < $1.price })
    }

    // Get a subscription's level of service using the product ID.
    func entitlement(for status: Product.SubscriptionInfo.Status) -> ServiceEntitlement {
        // If the status is expired, then the customer is not entitled.
        if status.state == .expired || status.state == .revoked {
            return .notEntitled
        }
        // Get the product associated with the subscription status.
        let productID = status.transaction.unsafePayloadValue.productID
        guard let product = subscriptions.first(where: { $0.id == productID }) else {
            return .notEntitled
        }
        // Finally, get the corresponding entitlement for this product.
        return ServiceEntitlement(for: product) ?? .notEntitled
    }
}
