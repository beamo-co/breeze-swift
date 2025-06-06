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
                print("Failed to fetch StoreKit products: \(error)")
            }
        }
        
//         // Fetch products from Breeze backend
//         var url = baseURL.appendingPathComponent("/iap/products")
//        url.append
//         var request = createApiRequest(url: url)
//         request.httpMethod = "GET"
//        
//         let body = ["product_ids": productIds]
//         request.httpBody = try JSONEncoder().encode(body)
//        
//         let (data, response) = try await session.data(for: request)
//        
//         guard let httpResponse = response as? HTTPURLResponse,
//               (200...299).contains(httpResponse.statusCode) else {
//             throw BreezeError.networkError
//         }
//        
//         // Parse backend response and combine with StoreKit products
//         let backendProducts = try JSONDecoder().decode([BreezeBackendProduct].self, from: data)

        // Mock backend products for testing
        let backendProducts: [BreezeBackendProduct] = [
            BreezeBackendProduct(
                id: productIds[0],
                displayName: "100 Coins",
                description: "Get 100 coins to use in the game",
                price: Decimal(0.99),
                displayPrice: "$0.99",
                currencyCode: "USD",
                breezeProductId: "breeze_coin_100",
                purchaseUrl: URL(string: "https://breeze.example.com/purchase/coin_100")!,
                type: .consumable
            ),
            BreezeBackendProduct(
                id: productIds[1],
                displayName: "500 Coins",
                description: "Get 500 coins to use in the game",
                price: Decimal(4.99),
                displayPrice: "$4.99",
                currencyCode: "USD",
                breezeProductId: "breeze_coin_500",
                purchaseUrl: URL(string: "https://breeze.example.com/purchase/coin_500")!,
                type: .consumable
            ),
            BreezeBackendProduct(
                id: productIds[2],
                displayName: "Premium Monthly",
                description: "Premium features for one month",
                price: Decimal(9.99),
                displayPrice: "$9.99",
                currencyCode: "USD",
                breezeProductId: "breeze_premium_monthly",
                purchaseUrl: URL(string: "https://breeze.example.com/purchase/premium_monthly")!,
                type: .autoRenewable
            )
        ]
        
        return backendProducts.map { backendProduct in
            let storeProduct = storeProducts.first { $0.id == backendProduct.id }
            
            return BreezeProduct(
                id: backendProduct.id,
                displayName: backendProduct.displayName,
                description: backendProduct.description,
                price: backendProduct.price,
                displayPrice: backendProduct.displayPrice,
                currencyCode: backendProduct.currencyCode,
                storeProduct: storeProduct,
                breezeProductId: backendProduct.breezeProductId,
                purchaseUrl: backendProduct.purchaseUrl,
                type: backendProduct.type
            )
        }
    }
    
    public func fromSkProduct(skProduct: Product) async throws -> BreezeProduct {
        let backendProduct = BreezeBackendProduct(
            id: skProduct.id,
            displayName: "Premium Monthly",
            description: "Premium features for one month",
            price: Decimal(9.99),
            displayPrice: "$9.99",
            currencyCode: "USD",
            breezeProductId: "breeze_premium_monthly",
            purchaseUrl: URL(string: "https://breeze.example.com/purchase/premium_monthly")!,
            type: .autoRenewable
        )
        return BreezeProduct(
            id: backendProduct.id,
            displayName: backendProduct.displayName,
            description: backendProduct.description,
            price: backendProduct.price,
            displayPrice: backendProduct.displayPrice,
            currencyCode: backendProduct.currencyCode,
            storeProduct: skProduct,
            breezeProductId: backendProduct.breezeProductId,
            purchaseUrl: backendProduct.purchaseUrl,
            type: backendProduct.type
        )
    }
}

