import Foundation
import StoreKit

extension Breeze {
    // MARK: - Product related
    public func products(productIds: [String]) async throws -> [BreezeProduct] {
        guard self.isConfigured else {
            throw BreezeError.notConfigured
        }
        
        // First try to fetch StoreKit products if available
        var storeProducts: [Product] = []
        if #available(iOS 15.0, *) {
            do {
                storeProducts = try await Product.products(for: productIds)
            } catch {
                // Log StoreKit fetch error but continue with backend fetch
                print("[Breeze] Failed to fetch StoreKit products: \(error)")
            }
        }
        
        // Fetch products from Breeze serverÏÏ
        var backendProducts: [BreezeBackendProduct] = []
        do {
            let backendProductApiRes: BreezeGetProductsApiResponse = try await getRequest(
                path: "/iap/client/products",
                queryParams: ["productIds": productIds.joined(separator: ",")]
            )
            backendProducts = backendProductApiRes.data.products
        } catch {
            //pass
            print("[Breeze] Failed to fetch backend products: \(error)")
        }

        // if no BE products, fallback to SkProducts
        if(backendProducts.count == 0) {
            return storeProducts.map { storeProduct in
                var breezeProductType = BreezeProduct.ProductType.consumable
                if(storeProduct.type == .autoRenewable) {
                    breezeProductType = .autoRenewable
                } else if(storeProduct.type == .nonConsumable) {
                    breezeProductType = .nonConsumable
                } else if(storeProduct.type == .consumable) {
                    breezeProductType = .consumable
                }
                return BreezeProduct(
                    id: storeProduct.id,
                    displayName: storeProduct.displayName,
                    description: storeProduct.description,
                    price: storeProduct.price,
                    displayPrice: storeProduct.displayPrice,
                    currencyCode: "USD", //default to USD
                    storeProduct: storeProduct,
                    breezeProductId: storeProduct.id,
                    type: breezeProductType,
                    existInBreeze: false
                )
            }
        }
       
        // // Mock backend products for testing
        // let mockBackendProducts: [BreezeBackendProduct] = [
        //     BreezeBackendProduct(
        //         id: productIds[0],
        //         displayName: "100 Coins",
        //         description: "Get 100 coins to use in the game",
        //         price: Decimal(0.99),
        //         displayPrice: "$0.99",
        //         currencyCode: "USD",
        //         breezeProductId: "breeze_coin_100",
        //         purchaseUrl: URL(string: "https://breeze.example.com/purchase/coin_100")!,
        //         type: .consumable
        //     ),
        //     BreezeBackendProduct(
        //         id: productIds[1],
        //         displayName: "500 Coins",
        //         description: "Get 500 coins to use in the game",
        //         price: Decimal(4.99),
        //         displayPrice: "$4.99",
        //         currencyCode: "USD",
        //         breezeProductId: "breeze_coin_500",
        //         purchaseUrl: URL(string: "https://breeze.example.com/purchase/coin_500")!,
        //         type: .consumable
        //     ),
        //     BreezeBackendProduct(
        //         id: productIds[2],
        //         displayName: "Premium Monthly",
        //         description: "Premium features for one month",
        //         price: Decimal(9.99),
        //         displayPrice: "$9.99",
        //         currencyCode: "USD",
        //         breezeProductId: "breeze_premium_monthly",
        //         purchaseUrl: URL(string: "https://breeze.example.com/purchase/premium_monthly")!,
        //         type: .autoRenewable
        //     )
        // ]
        
        return backendProducts.map { backendProduct in
            let storeProduct = storeProducts.first { $0.id == backendProduct.id }
            
            return BreezeProduct(
                id: backendProduct.id,
                displayName: backendProduct.displayName,
                description: backendProduct.description,
                price: Decimal(string: String(backendProduct.price)) ?? Decimal(0),
                displayPrice: backendProduct.displayPrice,
                currencyCode: "USD",
                storeProduct: storeProduct,
                breezeProductId: backendProduct.id,
                type: backendProduct.type,
                existInBreeze: true
            )
        }
    }
    
    public func fromSkProduct(skProduct: Product) async throws -> BreezeProduct {
//        let backendProduct = BreezeBackendProduct(
//            id: skProduct.id,
//            displayName: "Premium Monthly",
//            description: "Premium features for one month",
//            price: Decimal(9.99),
//            displayPrice: "$9.99",
//            currencyCode: "USD",
//            breezeProductId: "breeze_premium_monthly",
//            purchaseUrl: URL(string: "https://breeze.example.com/purchase/premium_monthly")!,
//            type: .autoRenewable
//        )

        var backendProducts: [BreezeBackendProduct] = []
        do {
            let backendProductApiRes: BreezeGetProductsApiResponse = try await getRequest(
                path: "/iap/client/products",
                queryParams: ["productIds": skProduct.id]
            )
            backendProducts = backendProductApiRes.data.products
        } catch {
            //pass
            print("[Breeze] Failed to fetch backend products: \(error)")
        }

        
        var breezeProductType = BreezeProduct.ProductType.consumable
        if(skProduct.type == .autoRenewable) {
            breezeProductType = .autoRenewable
        } else if(skProduct.type == .nonConsumable) {
            breezeProductType = .nonConsumable
        } else if(skProduct.type == .consumable) {
            breezeProductType = .consumable
        }
        return BreezeProduct(
            id: skProduct.id,
            displayName: skProduct.displayName,
            description: skProduct.description,
            price: skProduct.price,
            displayPrice: skProduct.displayPrice,
            currencyCode: "USD", //default to USD
            storeProduct: skProduct,
            breezeProductId: skProduct.id,
            type: breezeProductType,
            existInBreeze: backendProducts.count > 0
        )
    }
}

