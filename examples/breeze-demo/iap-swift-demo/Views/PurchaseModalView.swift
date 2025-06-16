import SwiftUI
import StoreKit

struct PurchaseModalView: View {
    let product: BreezeProduct
    @EnvironmentObject private var breezeStoreKitManager: BreezeStoreKitManager
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKitManager = StoreKitManager()
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Product Image
                    Image(systemName: "dollarsign.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                    
                    // Product Info
                    VStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text(product.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                        
                        Text(product.price, format: .currency(code: "USD"))
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.top, 4)
                    }
                    .padding()
                    
                    // Purchase Buttons
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await purchaseWithStoreKit()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "apple.logo")
                                Text("Purchase with Apple Pay")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isPurchasing)
                        
                        Button {
                            Task {
                                await purchaseWithWeb()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text("Purchase with Web")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isPurchasing)
                    }
                    .padding(.horizontal)
                    .padding()
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert(item: $breezeStoreKitManager.alertItem) { alertItem in
                       Alert(
                        title: Text(alertItem.title),
                           message: Text(alertItem.message),
                           dismissButton: .default(Text("OK")) {
                               dismiss()
                           }
                       )
                   }
        }
        .preferredColorScheme(.dark)
    }
    
    private func purchaseWithStoreKit() async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            if let _ = try await breezeStoreKitManager.purchaseSk(product) {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        isPurchasing = false
    }
    
    private func purchaseWithWeb() async {
        do {
            if let _ = try await BreezeStoreKitManager.shared.purchase(product) {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
}
