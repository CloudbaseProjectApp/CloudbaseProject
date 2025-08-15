import SwiftUI
import Foundation

// Global Session wrapper to handle network timeouts, error handling, etc. on URL calls
// Also handles JSON, data, text (including KML) results from session calls

final class AppSession {
    static let shared = AppSession()
    let session: URLSession
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        config.httpMaximumConnectionsPerHost = 6
        self.session = URLSession(configuration: config)
    }
    
    // Allow creating custom sessions if needed
    static func withConfiguration(_ config: URLSessionConfiguration) -> AppSession {
        return AppSession(session: URLSession(configuration: config))
    }
    
    private init(session: URLSession) {
        self.session = session
    }
}

enum AppNetworkError: Error {
    case noData
    case serverError(statusCode: Int)
    case decodingFailed(Error)
    case other(Error)
}

final class AppNetwork {
    static let shared = AppNetwork(session: AppSession.shared.session)
    private let session: URLSession
    private init(session: URLSession) {
        self.session = session
    }
    
    // Factory for custom sessions
    static func withSession(_ session: URLSession) -> AppNetwork {
        return AppNetwork(session: session)
    }
        
    // Centralized Logging based on global debug settings
    func logURL(_ url: URL?) {
        if printURLRequest {
            if let url = url {
                print("[AppNetwork] Request URL: \(url.absoluteString)")
            } else {
                print("[AppNetwork] Request URL: <missing URL>")
            }
        }
    }
    func logRawResponse(_ data: Data) {
        if printURLRawResponse {
            if let rawString = String(data: data, encoding: .utf8) {
                print("[AppNetwork] Raw Response:\n\(rawString)")
            } else {
                print("[AppNetwork] Raw Response (non-UTF8, \(data.count) bytes)")
            }
        }
    }
    
    // Error Handling
    func handleNetworkError(_ error: Error) {
        print("[AppNetwork] Network Error: \(error.localizedDescription)")
    }
    func handleDecodingError(_ error: Error) {
        print("[AppNetwork] Decoding Error: \(error.localizedDescription)")
    }
    
    // Generic GET
    func fetchJSON<T: Decodable>(
        url: URL,
        type: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        logURL(url)
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                self.handleNetworkError(error)
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            self.logRawResponse(data)
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                self.handleDecodingError(error)
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Async GET JSON
    func fetchJSONAsync<T: Decodable>(
        url: URL,
        type: T.Type
    ) async throws -> T {
        logURL(url)
        let (data, _) = try await URLSession.shared.data(from: url)
        logRawResponse(data)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // Async GET Data
    func fetchDataAsync(url: URL) async throws -> Data {
        logURL(url)
        let (data, _) = try await URLSession.shared.data(from: url)
        logRawResponse(data)
        return data
    }
    func fetchDataAsync(request: URLRequest) async throws -> Data {
        logURL(request.url)
        let (data, _) = try await URLSession.shared.data(for: request)
        logRawResponse(data)
        return data
    }
    
    // Async GET Text
    func fetchTextAsync(url: URL) async throws -> String {
        logURL(url)
        let (data, _) = try await URLSession.shared.data(from: url)
        logRawResponse(data)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        return text
    }
    func fetchTextAsync(request: URLRequest) async throws -> String {
        logURL(request.url)
        let (data, _) = try await URLSession.shared.data(for: request)
        logRawResponse(data)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        return text
    }
    
    // POST JSON (no token)
    func postJSON<T: Encodable>(
        url: URL,
        body: T
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        _ = try await URLSession.shared.data(for: request)
    }
    func postJSON<T: Encodable, U: Decodable>(
        url: URL,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        let (data, _) = try await URLSession.shared.data(for: request)
        logRawResponse(data)
        return try JSONDecoder().decode(U.self, from: data)
    }
    
    // POST JSON (with token)
    func postJSON<T: Encodable>(
        url: URL,
        token: String,
        body: T
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        _ = try await URLSession.shared.data(for: request)
    }
    func postJSON<T: Encodable, U: Decodable>(
        url: URL,
        token: String,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        let (data, _) = try await URLSession.shared.data(for: request)
        logRawResponse(data)
        return try JSONDecoder().decode(U.self, from: data)
    }
    
    // PUT JSON (no token)
    func putJSON<T: Encodable>(
        url: URL,
        body: T
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        _ = try await URLSession.shared.data(for: request)
    }
    func putJSON<T: Encodable, U: Decodable>(
        url: URL,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        let (data, _) = try await URLSession.shared.data(for: request)
        logRawResponse(data)
        return try JSONDecoder().decode(U.self, from: data)
    }
    
    // PUT JSON (with token)
    func putJSON<T: Encodable>(
        url: URL,
        token: String,
        body: T
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        _ = try await URLSession.shared.data(for: request)
    }
    func putJSON<T: Encodable, U: Decodable>(
        url: URL,
        token: String,
        body: T,
        responseType: U.Type
    ) async throws -> U {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        logURL(url)
        let (data, _) = try await URLSession.shared.data(for: request)
        logRawResponse(data)
        return try JSONDecoder().decode(U.self, from: data)
    }
}
