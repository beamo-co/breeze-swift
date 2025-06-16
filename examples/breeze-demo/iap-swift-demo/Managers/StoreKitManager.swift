/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The class responsible for requesting products from the App Store and starting purchases.
*/

import Foundation
import StoreKit

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

public enum StoreError: Error {
    case failedVerification
}

class StoreKitManager: ObservableObject {
    @Published private(set) var nonConsumableProducts: [Product]
    @Published private(set) var consumableProducts: [Product]
    
    @Published private(set) var purchasedNonConsumableProducts: [Product] = []
    private let productIds: [String]
    
    var updateListenerTask: Task<Void, Error>? = nil

    init() {
        // Initialize empty products, then do a product request asynchronously to fill them in.
        nonConsumableProducts = []
        consumableProducts = []
        productIds = [
            "consumable.fuel.octane87", "consumable.fuel.octane89", "consumable.fuel.octane91"
        ]

        // Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            // During store initialization, request products from the App Store.
            await requestProducts()

            // Deliver products that the customer purchases.
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }


    func listenForTransactions() -> Task<Void, Error> {
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
            let storeProducts = try await Product.products(for: productIds)

            // Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    consumableProducts.append(product)
                case .nonConsumable:
                    nonConsumableProducts.append(product)
//                case .autoRenewable:
//                    newSubscriptions.append(product)
//                case .nonRenewable:
//                    newNonRenewables.append(product)
                default:
                    // Ignore this product.
                    print("Unknown product.")
                }
            }
        } catch {
            print("Failed product request from the App Store server. \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        // Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Check whether the transaction is verified. If it isn't,
            // this function rethrows the verification error.
            let transaction = try checkVerified(verification)

            // The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()

            // Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    func isPurchased(_ product: Product) async throws -> Bool {
        // Determine whether the user purchases a given product.
        switch product.type {
        case .nonConsumable:
            return purchasedNonConsumableProducts.contains(product)
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
        var purchasedNonConsumable: [Product] = []

        // Iterate through all of the user's purchased products.
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                // Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)

                // Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .nonConsumable:
                    if let product = nonConsumableProducts.first(where: { $0.id == transaction.productID }) {
                        purchasedNonConsumable.append(product)
                    }
                default:
                    break
                }
            } catch {
                print()
            }
        }

        // Update the store information with the purchased products.
        self.purchasedNonConsumableProducts = purchasedNonConsumable
    }

    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }

//    // Get a subscription's level of service using the product ID.
//    func entitlement(for status: Product.SubscriptionInfo.Status) -> ServiceEntitlement {
//        // If the status is expired, then the customer is not entitled.
//        if status.state == .expired || status.state == .revoked {
//            return .notEntitled
//        }
//        // Get the product associated with the subscription status.
//        let productID = status.transaction.unsafePayloadValue.productID
//        guard let product = subscriptions.first(where: { $0.id == productID }) else {
//            return .notEntitled
//        }
//        // Finally, get the corresponding entitlement for this product.
//        return ServiceEntitlement(for: product) ?? .notEntitled
//    }
}
