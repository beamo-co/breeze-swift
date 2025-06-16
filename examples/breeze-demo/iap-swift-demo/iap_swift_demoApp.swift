//
//  iap_swift_demoApp.swift
//  iap-swift-demo
//
//  Created by AndreasS on 3/6/25.
//

import SwiftUI

@main
struct iap_swift_demoApp: App {
    init() {
        Breeze.shared.configure(with: BreezeConfiguration(
            apiKey: "test_1688d60f-121b-4d3e-9e65-ece35476fbd1",
            appScheme: "testappbreeze://",
            userId: String(UIDevice.current.identifierForVendor?.uuidString ?? ""),
            environment: .sandbox
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(BreezeStoreKitManager.shared)
                .onOpenURL { url in
                    Breeze.shared.verifyUrl(url)
                }
        }
    }
}
