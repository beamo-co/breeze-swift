/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A product view for an individual fuel type.
*/

import SwiftUI
import StoreKit
import Breeze

struct FuelProductView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var store: Store
    @State private var errorTitle = ""
    @State private var isShowingError = false

    let fuel: BreezeProduct
    let onPurchase: (BreezeProduct) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(store.emoji(for: fuel.id))
                .font(.system(size: 120))
            Text(fuel.description)
                .bold()
                .foregroundColor(Color.black)
                .clipShape(Rectangle())
                .padding(10)
                .background(Color.yellow)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 2)
                )
                .padding(.bottom, 5)
            buyButton
                .buttonStyle(BuyButtonStyle())
        }
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("Okay")))
        })
    }

    var buyButton: some View {
        Button(action: {
            Task {
                await purchaseWeb()
            }
        }) {
            Text(fuel.displayPrice)
                .foregroundColor(.white)
                .bold()
        }
    }

    @MainActor
    func purchaseWeb() async {
        do {
            let _ = try await store.purchaseWeb(fuel, onSuccess: {
                onPurchase(fuel)
            })
        } catch {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        }
    }
}
