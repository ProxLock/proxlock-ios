// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import DeviceCheck

/// The primary networking request layer for a ProxLock key. We recommend that you use one ``PLSession`` per API key in your app. This will make it far easier to manage.
///
/// - Important: For ``PLSession`` and ProxLock to work correctly, you must enable `App Attest` in your `Signing & Capabilities` tab for the target.
public class PLSession {
    /// The partial key shared by ProxLock when you added your bearer token to the web portal.
    public let partialKey: String
    
    /// The id for a this key in ProxLock.
    public let associationID: String
    
    /// The string that will ultimately be replaced by ProxLock with the final bearer token.
    public var bearerToken: String {
        "%ProxLock_PARTIAL_KEY:\(partialKey)%"
    }
    
    /// Initializes ``PLSession``.
    ///
    /// - Parameters:
    ///   - partialKey: The partial key shared by ProxLock when you added your bearer token to the web portal.
    ///   - assosiationID: The id for a this key in ProxLock.
    public init(partialKey: String, associationID: String) {
        self.partialKey = partialKey
        self.associationID = associationID
    }
    
    /// Translates your `URLRequest` into an object for ProxLock.
    ///
    /// - Important: This does not include any form of authorization header. To use the bearer token, simply call ``bearerToken`` where you would like the real token to be constructed.
    public func processURLRequest(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        
        guard let destinationURL = request.url, let destinationMethod = request.httpMethod else {
            throw URLError(.badURL)
        }
        
        // Set proxy components
        request.url = URL(string: "https://api.proxlock.dev/proxy")
        request.httpMethod = "POST"
        
        // Update headers
        request.setValue(destinationURL.absoluteString, forHTTPHeaderField: "ProxLock_DESTINATION")
        request.setValue("device-check", forHTTPHeaderField: "ProxLock_VALIDATION_MODE")
        request.setValue(destinationMethod.uppercased(), forHTTPHeaderField: "ProxLock_HTTP_METHOD")
        request.setValue(associationID, forHTTPHeaderField: "ProxLock_ASSOCIATION_ID")
        if let deviceCheckToken = try await getDeviceCheckToken() {
            request.setValue(deviceCheckToken.base64EncodedString(), forHTTPHeaderField: "X-Apple-Device-Token")
        }
        
        return request
    }

    /// A basic data request wrapper for `URLSession` that automatically wraps the request for ProxLock.
    ///
    /// - Important: This does not include any form of authorization header. To use the bearer token, simply call ``bearerToken`` where you would like the real token to be constructed.
    public func data(from url: URL, from session: URLSession = .shared) async throws -> (Data, URLResponse) {
        return try await data(for: URLRequest(url: url), from: session)
    }
    
    /// A basic data request wrapper for `URLSession` that automatically wraps the request for ProxLock.
    ///
    /// - Important: This does not include any form of authorization header. To use the bearer token, simply call ``bearerToken`` where you would like the real token to be constructed.
    public func data(for request: URLRequest, from session: URLSession = .shared) async throws -> (Data, URLResponse) {
        let request = try await processURLRequest(request)
        
        return try await session.data(for: request)
    }
    
    /// Generated token used for Apple Device Check
    private func getDeviceCheckToken() async throws -> Data? {
        #if targetEnvironment(simulator)
        guard let bypassToken = ProcessInfo.processInfo.environment["PROXLOCK_DEVICE_CHECK_BYPASS"] else {
            throw DCError(.featureUnsupported)
        }
        
        return bypassToken.data(using: .utf8)
        #else
        guard DCDevice.current.isSupported else {
            throw DCError(.featureUnsupported)
        }
        
        let token: Data? = try await withCheckedThrowingContinuation { continuation in
            DCDevice.current.generateToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: token)
            }
        }
        
        return token
        #endif
    }
}
