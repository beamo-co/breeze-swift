# Breeze Swift SDK

Breeze SDK is a powerful and seamless In-App Purchase (IAP) SDK for iOS applications, built with modern Swift and fully compatible with StoreKit 2. Our SDK simplifies the integration of in-app purchases, making it easier for developers to implement and manage purchases in their applications.

## Features

- 🚀 Full StoreKit 2 compatibility
- 💰 Seamless in-app purchase integration
- 🔒 Secure transaction handling
- 📱 Support for all iOS devices
- 🛠 Simple and intuitive API

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- StoreKit 2

## Installation

### Swift Package Manager

The Breeze SDK is available through Swift Package Manager. To install it, add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/beamo-co/breeze-swift.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. Go to File > Add Packages
2. Enter the repository URL: `https://github.com/beamo-co/breeze-swift.git`
3. Select the version you want to use
4. Click Add Package


## Usage

### Initialization

First, import the SDK and initialize it in your app:

```swift
import Breeze

// In your AppDelegate or main app file
@main
struct exampleApp: App {
    init() {
        //1) Initialize app using shared singleton Breeze instance
        Breeze.shared.configure(with: BreezeConfiguration(
            apiKey: "API_KEY", //breeze client API Key
            appScheme: "testapp://", //your deeplink app scheme or universal link
            //optional
            userId: "" //unique user ID as identifier who made the purchae
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            //2) add redirection listener
            .onOpenURL { url in
                Breeze.shared.verifyUrl(url)
            }
        }
    }
}
```


#### Configuring App URL Scheme

To enable deep linking in your app, you need to configure a custom URL scheme:

1. Open your Xcode project
2. Select your target
3. Go to the "Info" tab
4. Expand "URL Types"
5. Click the "+" button to add a new URL type
6. In the "URL Schemes" field, enter your app's scheme (e.g., "testapp")
7. The full URL scheme will be "testapp://"

![URL Scheme Configuration](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app/url-scheme-configuration.png)

This URL scheme should match the `appScheme` parameter you provide when configuring Breeze


### Get Products

```swift
let breezeProducts = try await Breeze.shared.products(["IAP_PRODUCT_ID"])

//OR if you have existing storekit Product
let breezeProduct = try await Breeze.shared.fromSkProduct(skProduct: product)
```

### Making a Purchase

```swift
// Example of purchasing a product from storekit Product
 func purchaseWeb(_ product: Product) async throws {
    let breezeProduct = try await Breeze.shared.fromSkProduct(skProduct: product)

    try await breezeProduct.purchase(using: Breeze.shared, onSuccess: { transaction in
        //YOUR LOGIC on success purchase
        Task {
            await transaction.finish(using: Breeze.shared) //always finish transaction
        }
    })
}
```


## Support

For support, please:
- Open an issue on our GitHub repository
- Contact our support team at support@breeze.cash
- Check our [documentation](https://docs.breeze.cash)

## License

Breeze SDK is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for more details.
