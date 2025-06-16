/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The entry point for the app.
*/

import SwiftUI
import Breeze

@main
struct SKDemoApp: App {
    init() {
        Breeze.shared.configure(with: BreezeConfiguration(
            apiKey: "test_1688d60f-121b-4d3e-9e65-ece35476fbd1",
            appScheme: "testappledemo69a37a181403://",
            userId: String(UIDevice.current.identifierForVendor?.uuidString ?? ""),
            environment: .sandbox
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            MyCarsView()
                .onOpenURL { url in
                    Breeze.shared.verifyUrl(url)
                }
        }
        
    }
}
