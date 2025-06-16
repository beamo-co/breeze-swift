import SwiftUI

struct HomepageView: View {
    @EnvironmentObject private var breezeStoreKitManager: BreezeStoreKitManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Image
                Image("breezy-game-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Content
                VStack {
                    Spacer()
                    
                    // Title
                    Text("Brezzy")
                        .font(.system(size: 52))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    
                    Spacer()
                    Spacer()
                    
                    // Shop Button
                    NavigationLink(destination: ShopView()) {
                        Text("Enter Shop")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

#Preview {
    HomepageView()
        .environmentObject(BreezeStoreKitManager.shared)
}
