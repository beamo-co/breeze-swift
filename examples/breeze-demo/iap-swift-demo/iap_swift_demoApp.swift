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
            apiKey: "sandbox_abcdef",
            appScheme: "testapp-andreas://"
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(BreezeStoreKitManager.shared)
                .onOpenURL { url in
                    print("URL", url)
                    Breeze.shared.verifyUrl(url)
                }
        }
    }
}
