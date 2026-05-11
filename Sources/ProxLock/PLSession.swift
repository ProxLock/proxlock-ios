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
    
    /// The API URL used for ProxLock
    public var apiURL: URL
    
    /// The string that will ultimately be replaced by ProxLock with the final bearer token.
    public var bearerToken: String {
        "%ProxLock_PARTIAL_KEY:\(partialKey)%"
    }
    
    /// Initializes ``PLSession``.
    ///
    /// - Parameters:
    ///   - partialKey: The partial key shared by ProxLock when you added your bearer token to the web portal.
    ///   - assosiationID: The id for a this key in ProxLock.
    ///   - apiURL: The API URL used for ProxLock (defaults to `api.proxlock.dev`)
    public init(partialKey: String, associationID: String, apiURL: URL = URL(string: "https://api.proxlock.dev")!) {
        self.partialKey = partialKey
        self.associationID = associationID
        self.apiURL = apiURL
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
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            request.url = apiURL.appending(path: "proxy")
        } else {
            // Fallback on earlier versions
            request.url = apiURL.appendingPathComponent("proxy")
        }
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

    /// Translates your WebSocket `URLRequest` into an object for ProxLock.
    ///
    /// - Important: This does not include any form of authorization header. To use the bearer token, simply call ``bearerToken`` where you would like the real token to be constructed.
    public func processWebSocketRequest(_ request: URLRequest) async throws -> URLRequest {
        var request = request

        guard let destinationURL = request.url else {
            throw URLError(.badURL)
        }

        guard ["ws", "wss"].contains(destinationURL.scheme?.lowercased()) else {
            throw URLError(.unsupportedURL)
        }

        request.url = proxyURL(appendingPathComponents: ["proxy", "ws"], webSocket: true)
        request.httpMethod = "GET"

        request.setValue(destinationURL.absoluteString, forHTTPHeaderField: "ProxLock_DESTINATION")
        request.setValue("device-check", forHTTPHeaderField: "ProxLock_VALIDATION_MODE")
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

    /// A basic WebSocket wrapper for `URLSession` that automatically wraps the request for ProxLock.
    ///
    /// - Important: This does not include any form of authorization header. To use the bearer token, simply call ``bearerToken`` where you would like the real token to be constructed.
    public func webSocketTask(with url: URL, from session: URLSession = .shared) async throws -> URLSessionWebSocketTask {
        return try await webSocketTask(with: URLRequest(url: url), from: session)
    }

    /// A basic WebSocket wrapper for `URLSession` that automatically wraps the request for ProxLock.
    ///
    /// - Important: This does not include any form of authorization header. To use the bearer token, simply call ``bearerToken`` where you would like the real token to be constructed.
    public func webSocketTask(with request: URLRequest, from session: URLSession = .shared) async throws -> URLSessionWebSocketTask {
        let request = try await processWebSocketRequest(request)

        return session.webSocketTask(with: request)
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

    private func proxyURL(appendingPathComponents pathComponents: [String], webSocket: Bool) -> URL {
        var url = apiURL

        for pathComponent in pathComponents {
            if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
                url = url.appending(path: pathComponent)
            } else {
                url = url.appendingPathComponent(pathComponent)
            }
        }

        guard webSocket, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        default:
            break
        }

        return components.url ?? url
    }
}
