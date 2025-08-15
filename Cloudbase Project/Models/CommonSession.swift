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

// App Network helper to standardize JSON and text calls with error handling, etc.
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
    
    // Internal generic dataTask helper
    private func dataTask(
        url: URL,
        completion: @escaping (Result<Data, AppNetworkError>) -> Void
    ) {
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.other(error)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            completion(.success(data))
        }
        task.resume()
    }
    
    // Public JSON fetch
    func fetchJSON<T: Decodable>(
        url: URL,
        type: T.Type,
        completion: @escaping (Result<T, AppNetworkError>) -> Void
    ) {
        dataTask(url: url) { result in
            switch result {
            case .success(let data):

                // Debug print statements
                if printURLRawResponse {
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("🔍 Raw JSON from \(url):\n\(rawString)")
                    } else {
                        print("⚠️ Unable to decode raw data as UTF-8 from \(url)")
                    }
                }

                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(.decodingFailed(error)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchJSONAsync<T: Decodable>(url: URL, type: T.Type) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            self.fetchJSON(url: url, type: type) { result in
                switch result {
                case .success(let decoded):
                    cont.resume(returning: decoded)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    
    func postJSON(url: URL, token: String, body: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try await fetchTextAsync(request: req)
    }

    func putJSON(url: URL, token: String, body: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try await fetchTextAsync(request: req)
    }
    
    // Public Text fetch
    func fetchText(
        url: URL,
        completion: @escaping (Result<String, AppNetworkError>) -> Void
    ) {
        dataTask(url: url) { result in
            switch result {
            case .success(let data):
                
                // Debug print statements
                if printURLRawResponse {
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("🔍 Raw JSON from \(url):\n\(rawString)")
                    } else {
                        print("⚠️ Unable to decode raw data as UTF-8 from \(url)")
                    }
                }

                if let text = String(data: data, encoding: .utf8) {
                    completion(.success(text))
                } else {
                    completion(.failure(.noData))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Fetches a URL as a String asynchronously.
    func fetchTextAsync(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            fetchText(url: url) { result in
                switch result {
                case .success(let text):
                    continuation.resume(returning: text)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Executes a URLRequest asynchronously, honoring method, headers, and body
    func fetchTextAsync(request: URLRequest, printURLRawResponse: Bool = false) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: AppNetworkError.other(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: AppNetworkError.serverError(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1
                    ))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: AppNetworkError.noData)
                    return
                }
                
                // Debug print statements
                if printURLRawResponse {
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("🔍 Raw response from \(request.url?.absoluteString ?? "<unknown URL>"):\n\(rawString)")
                    } else {
                        print("⚠️ Unable to decode raw data as UTF-8 from \(request.url?.absoluteString ?? "<unknown URL>")")
                    }
                }
                
                guard let text = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: AppNetworkError.noData)
                    return
                }
                
                continuation.resume(returning: text)
            }
            task.resume()
        }
    }
    
    // Fetches a URL as Data asynchronously.
    func fetchDataAsync(url: URL) async throws -> Data {
        let text = try await fetchTextAsync(url: url)
        return Data(text.utf8)
    }
    
    // Fetches a URLRequest as Data asynchronously.
    func fetchDataAsync(request: URLRequest) async throws -> Data {
        let text = try await fetchTextAsync(request: request)
        return Data(text.utf8)
    }

}
