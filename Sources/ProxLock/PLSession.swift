// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import DeviceCheck

/// The primary networking request layer for a ProxLock key.
public class PLSession {
    public let partialKey: String
    public let assosiationID: String
    public var bearerToken: String {
        "%ProxLock_PARTIAL_KEY:\(partialKey)%"
    }
    
    public init(partialKey: String, assosiationID: String) {
        self.partialKey = partialKey
        self.assosiationID = assosiationID
    }
    
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
        request.setValue(assosiationID, forHTTPHeaderField: "ProxLock_ASSOCIATION_ID")
        if let deviceCheckToken = try await getDeviceCheckToken() {
            request.setValue(deviceCheckToken.base64EncodedString(), forHTTPHeaderField: "X-Apple-Device-Token")
        }
        
        return request
    }
    
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
