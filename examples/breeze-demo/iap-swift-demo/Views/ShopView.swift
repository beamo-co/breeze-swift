import SwiftUI
import StoreKit

struct ShopView: View {
    @State private var selectedProduct: BreezeProduct?
    @State private var showPurchaseModal = false
    @EnvironmentObject private var breezeStoreKitManager: BreezeStoreKitManager

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Image
                Image("breezy-game-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    Text("Shop")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                        .padding()
                    Text("Balance: \(breezeStoreKitManager.balance) Coin")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .padding(.bottom, 8)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(breezeStoreKitManager.consumableProducts) { product in
                            ProductCard(product: product)
                                .onTapGesture {
                                    selectedProduct = product
                                    showPurchaseModal.toggle()
                                }
                        }
                    }
                    .padding()
                }
                .toolbar(.visible, for: .navigationBar)
                .padding(.top, 0)
                .sheet(isPresented: Binding(
                    get: { showPurchaseModal },
                    set: { showPurchaseModal = $0 }
                )) {
                    if let product = selectedProduct {
                        PurchaseModalView(product: product)
                    }
                }
               
                
            }

        }
        .alert(item: $breezeStoreKitManager.alertItem) { alertItem in
                   Alert(
                    title: Text(alertItem.title),
                       message: Text(alertItem.message),
                       dismissButton: .default(Text("OK"))
                   )
               }
    }
}

struct ProductCard: View {
    let product: BreezeProduct

    var body: some View {
        VStack {
            // Product Image
            Image(systemName: "dollarsign.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.white)
                .padding(.top)
            
            // Product Info
            VStack(spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                
                Text(product.price, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.black))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ShopView()
        .environmentObject(BreezeStoreKitManager.shared)
}
