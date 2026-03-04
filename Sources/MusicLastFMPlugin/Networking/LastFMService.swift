import Foundation

@MainActor
class LastFMService {
    let apiKey: String
    let apiSecret: String
    
    init(apiKey: String, apiSecret: String) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }
    
    private let baseURL = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    
    func generateSignature(params: [String: String]) -> String {
        let sortedKeys = params.keys.sorted().filter { $0 != "api_sig" && $0 != "format" && $0 != "callback" }
        var sigString = ""
        for key in sortedKeys {
            sigString += "\(key)\(params[key]!)"
        }
        sigString += apiSecret
        return sigString.md5
    }
    
    func fetch<T: Decodable>(_ type: T.Type, method: String, params: [String: String] = [:], isPost: Bool = false) async throws -> T {
        var allParams = params
        allParams["method"] = method
        allParams["api_key"] = apiKey
        allParams["format"] = "json"
        
        if isPost {
            allParams["api_sig"] = generateSignature(params: allParams)
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            var components = URLComponents()
            components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let responseString = String(data: data, encoding: .utf8) {
                print("Last.fm Response: \(responseString)")
            }
            return try JSONDecoder().decode(T.self, from: data)
        } else {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
            components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}
