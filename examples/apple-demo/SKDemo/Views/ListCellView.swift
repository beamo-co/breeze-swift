/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view for an individual car or subscription product that shows a Buy button when it displays within the store.
*/

import SwiftUI
import StoreKit
import Breeze

struct ListCellView: View {
    @EnvironmentObject var store: Store
    @State var isPurchased: Bool = false
    @State var errorTitle = ""
    @State var isShowingError: Bool = false

    let product: BreezeProduct
    let purchasingEnabled: Bool

    var emoji: String {
        store.emoji(for: product.id)
    }

    init(product: BreezeProduct, purchasingEnabled: Bool = true) {
        self.product = product
        self.purchasingEnabled = purchasingEnabled
    }

    var body: some View {
        HStack {
            Text(emoji)
                .font(.system(size: 50))
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .padding(.trailing, 20)
            if purchasingEnabled {
                productDetail
                Spacer()
                buyButton
                    .buttonStyle(BuyButtonStyle(isPurchased: isPurchased))
                    .disabled(isPurchased)
            } else {
                productDetail
            }
        }
        .alert(isPresented: $isShowingError, content: {
            Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("Okay")))
        })
    }

    @ViewBuilder
    var productDetail: some View {
        if product.type == .autoRenewable {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .bold()
                Text(product.description)
            }
        } else {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .bold()
                Text(product.description)
            }
        }
    }

    func subscribeButton(_ subscription: Product.SubscriptionInfo) -> some View {
        let unit: String
        let plural = 1 < subscription.subscriptionPeriod.value
            switch subscription.subscriptionPeriod.unit {
        case .day:
            unit = plural ? "\(subscription.subscriptionPeriod.value) days" : "day"
        case .week:
            unit = plural ? "\(subscription.subscriptionPeriod.value) weeks" : "week"
        case .month:
            unit = plural ? "\(subscription.subscriptionPeriod.value) months" : "month"
        case .year:
            unit = plural ? "\(subscription.subscriptionPeriod.value) years" : "year"
        @unknown default:
            unit = "period"
        }

        return VStack {
            Text(product.displayPrice)
                .foregroundColor(.white)
                .bold()
                .padding(EdgeInsets(top: -4.0, leading: 0.0, bottom: -8.0, trailing: 0.0))
            Divider()
                .background(Color.white)
            Text(unit)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .padding(EdgeInsets(top: -8.0, leading: 0.0, bottom: -4.0, trailing: 0.0))
        }
    }

    var buyButton: some View {
        Button(action: {
            Task {
                await buy()
            }
        }) {
            if isPurchased {
                Text(Image(systemName: "checkmark"))
                    .bold()
                    .foregroundColor(.white)
            } else {
//                if let subscription = product.subscription {
//                    subscribeButton(subscription)
//                } else {
                    Text(product.displayPrice)
                        .foregroundColor(.white)
                        .bold()
//                }
            }
        }
        .onAppear {
            Task {
                isPurchased = (try? await store.isPurchased(product)) ?? false
            }
        }
    }

    func buy() async {
        do {
            try await store.purchase(product, onSuccess: {
                withAnimation {
                    isPurchased = true
                }
            })
        } catch StoreError.failedVerification {
            errorTitle = "Your purchase could not be verified by the App Store."
            isShowingError = true
        } catch {
            print("Failed purchase for \(product.id). \(error)")
        }
    }
}
