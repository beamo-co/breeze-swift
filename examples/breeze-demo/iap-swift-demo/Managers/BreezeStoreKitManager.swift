/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The class responsible for managing in-app purchases using Breeze SDK.
*/

import Foundation
import Breeze

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

class BreezeStoreKitManager: ObservableObject {
    // MARK: - Singleton
    public static let shared = BreezeStoreKitManager()
    
    @Published private(set) var nonConsumableProducts: [BreezeProduct] = []
    @Published private(set) var consumableProducts: [BreezeProduct] = []
    @Published private(set) var purchasedNonConsumableProducts: [BreezeProduct] = []
    @Published var alertItem: AlertItem?        // drives the sheet
    @Published private(set) var balance: Int {
        didSet {
            UserDefaults.standard.set(balance, forKey: "userBalance")
        }
    }

    private let productIds: [String]

    init() {
        self.productIds = [
            "consumable.fuel.octane87",
            "consumable.fuel.octane89", 
            "consumable.fuel.octane91"
        ]
        
        // Initialize balance from UserDefaults
        self.balance = UserDefaults.standard.integer(forKey: "userBalance")

        Task {
            await requestProducts()
            //setup pending listener
            Breeze.shared.setPurchaseCallback(onSuccess: onPurchaseSuccess)
        }
    }

    // MARK: - Balance Management
    func increaseBalance(by amount: Int) {
        balance += amount
    }

    deinit {
        updateListenerTask?.cancel()
    }

    @MainActor
    func requestProducts() async {
        do {
            let storeProducts = try await Breeze.shared.products(productIds: productIds)
            for product in storeProducts {
                switch product.type {
                case .consumable:
                    consumableProducts.append(product)
                case .nonConsumable:
                    nonConsumableProducts.append(product)
                default:
                    print("Unsupported product type: \(product.type)")
                }
            }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    func purchase(_ product: BreezeProduct) async throws -> BreezeTransaction? {
        _ = try await Breeze.shared.purchase(product, onSuccess: onPurchaseSuccess)
        //transaction always pending here
        return nil
    }
    
    func onPurchaseSuccess(_ transaction: BreezeTransaction) {
        alertItem = AlertItem(
            title: "Purchase Successful",
            message: "Purchase Successful"
        )
        increaseBalance(by: 10)
    }

    func purchaseSk(_ product: BreezeProduct) async throws -> BreezeTransaction? {
        let result = try await Breeze.shared.skPurchase(product, onSuccess: onPurchaseSuccess)
        if(result != nil){
            //transaction success, save in merchant database by validating the transaction ID
        }
        return nil
    }
    
    func isPurchased(_ product: BreezeProduct) async throws -> Bool {
        switch product.type {
        case .nonConsumable:
            return purchasedNonConsumableProducts.contains { $0.id == product.id }
        default:
            return false
        }
    }


//    @MainActor
//    func updateCustomerProductStatus() async {
//        var purchasedNonConsumable: [BreezeProduct] = []
//
//        for await result in BreezeTransaction.currentEntitlements {
//            do {
//                let transaction = try checkVerified(result)
//                
//                if transaction.productType == .nonConsumable,
//                   let product = nonConsumableProducts.first(where: { $0.id == transaction.productID }) {
//                    purchasedNonConsumable.append(product)
//                }
//            } catch {
//                print("Failed to verify transaction: \(error)")
//            }
//        }
//
//        self.purchasedNonConsumableProducts = purchasedNonConsumable
//    }

    func sortByPrice(_ products: [BreezeProduct]) -> [BreezeProduct] {
        products.sorted { $0.price < $1.price }
    }
}

