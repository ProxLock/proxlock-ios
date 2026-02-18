# ProxLock

A Swift package that provides a secure and easy networking layer for proxying API requests through [ProxLock's](https://proxlock.dev) service.

To see ProxLock in action, check out our [Demo App](https://github.com/ProxLock/ProxLock-Demo)!

## Requirements

- **Swift**: 6.2 or later
- **Platforms**:
  - iOS 13.0+
  - macOS 10.15+
  - watchOS 6.0+
  - visionOS 1.0+
  - tvOS 13.0+

## Installation

### Swift Package Manager

Add ProxLock to your project using Swift Package Manager:

1. In Xcode, go to **File** → **Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/APIProxy/proxlock-ios
   ```
3. Select the version or branch you want to use
4. Add the package to your target

Alternatively, add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/APIProxy/proxlock-ios", from: "0.1.0")
]
```

## Usage

### Getting Started

1. **Obtain your credentials from ProxLock**:
   - Log in to the [ProxLock web portal](https://app.proxlock.dev)
   - Add your bearer token to get a partial key and association ID

2. **Create a PLSession instance**:
   ```swift
   import ProxLock
   
   let session = PLSession(
       partialKey: "your-partial-key",
       associationID: "your-association-id"
   )
   ```

### Making Requests

#### Using the Convenience Method

The easiest way to make requests is using the `data(for:from:)` method:

```swift
// Create your original request
var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
request.httpMethod = "GET"
request.setValue("Bearer \(session.bearerToken)", forHTTPHeaderField: "Authorization")

// Make the request through ProxLock
do {
    let (data, response) = try await session.data(for: request)
    // Handle the response
} catch {
    // Handle errors
}
```

#### Using processURLRequest

If you need more control, you can process the request manually:

```swift
var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
request.httpMethod = "GET"
request.setValue("Bearer \(session.bearerToken)", forHTTPHeaderField: "Authorization")

// Process the request for ProxLock
let proxiedRequest = try await session.processURLRequest(request)

// Use the proxied request with URLSession
let (data, response) = try await URLSession.shared.data(for: proxiedRequest)
```

### Bearer Token Replacement

ProxLock automatically replaces the `bearerToken` placeholder in your requests. Use `session.bearerToken` wherever you would normally use your full bearer token:

```swift
// The bearerToken property returns: "%ProxLock_PARTIAL_KEY:your-partial-key%"
// ProxLock will replace this with the actual bearer token server-side
request.setValue("Bearer \(session.bearerToken)", forHTTPHeaderField: "Authorization")
```

### Device Check Integration

ProxLock uses Apple's Device Check framework for device validation. This will happen automatically on real devices. For simulator testing, just pass in the `PROXLOCK_DEVICE_CHECK_BYPASS` environment variable with the token shared in the Device Check section for your project.

> Note: For ``PLSession`` and ProxLock to work correctly, you must enable `App Attest` in your `Signing & Capabilities` tab for the target.

### Best Practices

1. **One session per API key**: Create a separate `PLSession` instance for each API key you use in your app. This makes it easier to manage multiple keys.

2. **Reuse sessions**: Create your `PLSession` instances once and reuse them throughout your app's lifecycle.

3. **Error handling**: Always wrap ProxLock calls in do-catch blocks to handle potential errors:
   ```swift
   do {
       let (data, response) = try await session.data(for: request)
       // Process data
   } catch {
       print("ProxLock error: \(error)")
   }
   ```

## Support

For issues or questions, please open a [GitHub Issue](https://github.com/proxlock/proxlock-ios/issues).
