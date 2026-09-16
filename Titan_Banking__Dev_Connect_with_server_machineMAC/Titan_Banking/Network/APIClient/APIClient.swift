import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// APIClient
//
// ALL requests go through titan-gateway-go (port 8088).
//
//   iOS Simulator  →  localhost:8088  →  titan-gateway-go
//                                     ↳  titan-core-banking       :8080
//                                     ↳  titan-notifications-service :8084
//                                     ↳  titan-promotions-service  :8083
//                                     ↳  titan-loans-service       :8085
//
// Never call any downstream service directly.
// ─────────────────────────────────────────────────────────────────────────────

final class APIClient {
    static let shared = APIClient()

    // ── Environment switch ────────────────────────────────────────────────────
    // true  → local Docker  (gateway at http://<Mac-LAN-IP>:8088)
    // false → production    (set gatewayURL to your deployed gateway URL)
    private static let useLocalDocker = true

    // ── Single gateway base URL ───────────────────────────────────────────────
    // Simulator connects to localhost:8088.
    // Real device connects via Mac LAN IP (e.g. 10.30.3.163:8088) over Wi-Fi.
    var gatewayURL: String {
        if let custom = UserDefaults.standard.string(forKey: "custom_gateway_url"), !custom.isEmpty {
            return custom
        }
        guard Self.useLocalDocker else {
            return "https://titan-gateway.onrender.com"   // ← update when deploying
        }
        #if targetEnvironment(simulator)
        return "http://localhost:8088"
        #else
        return "http://10.30.3.163:8088"
        #endif
    }

    // ── URLSession ────────────────────────────────────────────────────────────
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        // Local Docker is fast — short timeout avoids long waits on wrong port
        cfg.timeoutIntervalForRequest  = useLocalDocker ? 15 : 60
        cfg.timeoutIntervalForResource = useLocalDocker ? 15 : 60
        return URLSession(configuration: cfg)
    }()

    private init() {}

    // ── Generic request — all endpoints ──────────────────────────────────────
    /// Routes through the gateway. Works for Endpoint, LoanEndpoint,
    /// PromotionEndpoint — they all produce a path that the gateway understands.
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        var urlRequest = try endpoint.urlRequest(base: gatewayURL)
        attachToken(&urlRequest)
        return try await performRequest(urlRequest, responseType: T.self)
    }

    // ── Loan helper (now via gateway /api/v1/loans/**) ────────────────────────
    func loanRequest<T: Decodable>(
        _ endpoint: LoanEndpoint,
        responseType: T.Type
    ) async throws -> T {
        // LoanEndpoint paths start with /api/v1/loans — routed by gateway → loans-service:8085
        var urlRequest = try endpoint.urlRequest(base: gatewayURL)
        attachToken(&urlRequest)
        return try await performRequest(urlRequest, responseType: T.self)
    }

    // ── Promotions helper (now via gateway /promotions/**, /api/v1/promotions/**) ──
    func promotionsRequest<T: Decodable>(
        _ endpoint: PromotionEndpoint,
        responseType: T.Type
    ) async throws -> T {
        // PromotionEndpoint paths start with /promotions/ or /api/...
        // All are routed by the gateway → titan-promotions-service:8083
        var urlRequest = try endpoint.urlRequest(base: gatewayURL)
        attachToken(&urlRequest)
        return try await performRequest(urlRequest, responseType: T.self)
    }

    // ── Notification helper (still via gateway) ───────────────────────────────
    func notificationRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await request(endpoint, responseType: T.self)
    }

    // ── Plain-text response (e.g. international transfer) ────────────────────
    func requestPlainText(_ endpoint: Endpoint) async throws -> String {
        var urlRequest = try endpoint.urlRequest(base: gatewayURL)
        attachToken(&urlRequest)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, data)
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
    }

    // ── Raw bytes (PDF statements) ────────────────────────────────────────────
    func requestData(_ endpoint: Endpoint) async throws -> Data {
        var urlRequest = try endpoint.urlRequest(base: gatewayURL)
        attachToken(&urlRequest)
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, data)
        }
        return data
    }

    // ── Device token registration ─────────────────────────────────────────────
    func registerDeviceToken(_ token: String) async throws {
        let endpoint = NotificationEndpoint.registerDeviceToken(
            DeviceTokenRequest(deviceToken: token, platform: "IOS")
        )
        var urlRequest = try endpoint.urlRequest(base: gatewayURL)
        attachToken(&urlRequest)
        let (_, _) = try await session.data(for: urlRequest)
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    private func attachToken(_ request: inout URLRequest) {
        if let token = TokenStorage.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func performRequest<T: Decodable>(
        _ urlRequest: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        #if DEBUG
        let statusIcon = (200..<300).contains(http.statusCode) ? "✅" : "❌"
        print("\(statusIcon) [\(http.statusCode)] \(urlRequest.httpMethod ?? "?") \(urlRequest.url?.path ?? "")")
        if !(200..<300).contains(http.statusCode),
           let body = String(data: data, encoding: .utf8) {
            print("   ↳ \(body.prefix(300))")
        }
        #endif

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode, data)
        }

        do {
            return try JSONDecoder.titan.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Decode error for \(T.self): \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("   Raw: \(raw.prefix(500))")
            }
            #endif
            throw error
        }
    }
}

// ─── API Errors ───────────────────────────────────────────────────────────────

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int, Data)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code, let data):
            if code == 401 { return "Session expired — please log in again." }
            if code == 429 { return "Too many requests — please wait a moment." }
            if code == 502 { return "A backend service is unavailable. Try again shortly." }
            if code == 503 { return "Server is starting up — please try again in a moment." }
            // Try to extract a JSON "error" or "message" field for a readable error
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let msg = obj["message"] as? String, !msg.isEmpty {
                    return msg
                }
                if let err = obj["error"] as? String, !err.isEmpty {
                    return err
                }
            }
            let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
            return "HTTP \(code): \(raw)"
        }
    }
}

// ─── JSON Decoder ─────────────────────────────────────────────────────────────

extension JSONDecoder {
    static let titan: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        // Handles backend dates like "2026-06-29T13:56:13.27711545" (variable sub-seconds)
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let stripped = raw.replacingOccurrences(
                of: "\\.\\d+", with: "", options: .regularExpression)
            let fmt = DateFormatter()
            fmt.locale   = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(identifier: "UTC")
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = fmt.date(from: stripped + "+0000") { return date }
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = fmt.date(from: stripped) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Cannot parse date: \(raw)"
            )
        }
        return d
    }()
}
