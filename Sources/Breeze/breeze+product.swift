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
                print("[Breeze] Failed to fetch StoreKit products: \(error)")
            }
        }
        
        // Fetch products from Breeze server
        var backendProducts: [BreezeBackendProduct] = []
        do {
            let backendProductApiRes: BreezeGetProductsApiResponse = try await getRequest(
                path: "/iap/client/products",
                queryParams: ["productIds": productIds.joined(separator: ",")]
            )
            backendProducts = backendProductApiRes.data.products
        } catch {
            print("[Breeze] Failed to fetch backend products: \(error)")
        }

        // if no BE products, fallback to SkProducts
        if(backendProducts.count == 0) {
            return storeProducts.map { storeProduct in
                let breezeProductType = parseSkProductType(storeProduct.type)
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
        var backendProducts: [BreezeBackendProduct] = []
        do {
            let backendProductApiRes: BreezeGetProductsApiResponse = try await getRequest(
                path: "/iap/client/products",
                queryParams: ["productIds": skProduct.id]
            )
            backendProducts = backendProductApiRes.data.products
        } catch {
            print("[Breeze] Failed to fetch backend products: \(error)")
        }

        let breezeProductType = parseSkProductType(skProduct.type)

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
            existInBreeze: Bool(backendProducts.count > 0)
        )
    }

    public func parseSkProductType(_ type: Product.ProductType) -> BreezeProduct.ProductType {
        var breezeProductType = BreezeProduct.ProductType.consumable
        if(type == .autoRenewable) {
            breezeProductType = .autoRenewable
        } else if(type == .nonConsumable) {
            breezeProductType = .nonConsumable
        } else if(type == .consumable) {
            breezeProductType = .consumable
        }
        return breezeProductType
    }
}
