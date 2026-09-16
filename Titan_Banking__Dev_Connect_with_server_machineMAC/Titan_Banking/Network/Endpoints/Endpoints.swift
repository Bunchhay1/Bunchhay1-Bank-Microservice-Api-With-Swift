import Foundation

// MARK: - Endpoint Protocol

protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var body: Encodable? { get }
    /// Query string params (e.g. Titan promotions quests/referrals use @RequestParam)
    var queryItems: [URLQueryItem]? { get }
}

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
}

extension Endpoint {
    var queryItems: [URLQueryItem]? { nil }

    func urlRequest(base: String) throws -> URLRequest {
        guard var components = URLComponents(string: base + path) else {
            throw URLError(.badURL)
        }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        return req
    }
}

// MARK: - User Endpoints
enum UserEndpoint: Endpoint {
    case getUser(Int)
    var path: String { if case .getUser(let id) = self { return "/api/v1/users/\(id)" }; return "" }
    var method: HTTPMethod { .GET }
    var body: Encodable? { nil }
}

// MARK: - Auth Endpoints

enum AuthEndpoint: Endpoint {
    case login(LoginRequest)
    case register(RegisterRequest)

    var path: String {
        switch self {
        case .login:    return "/api/v1/auth/login"
        case .register: return "/api/v1/auth/register"
        }
    }
    var method: HTTPMethod { .POST }
    var body: Encodable? {
        switch self {
        case .login(let r):    return r
        case .register(let r): return r
        }
    }
}

// MARK: - Account Endpoints

enum AccountEndpoint: Endpoint {
    case getMyAccounts
    case getAccount(Int)
    case createAccount(CreateAccountRequest)

    var path: String {
        switch self {
        case .getMyAccounts:         return "/api/v1/accounts"
        case .getAccount(let id):    return "/api/v1/accounts/\(id)"
        case .createAccount:         return "/api/v1/accounts"
        }
    }
    var method: HTTPMethod {
        switch self {
        case .createAccount: return .POST
        default:             return .GET
        }
    }
    var body: Encodable? {
        switch self {
        case .createAccount(let r): return r
        default: return nil
        }
    }
}

// MARK: - Transaction Endpoints

enum TransactionEndpoint: Endpoint {
    case history
    case transfer(TransactionRequest)
    case deposit(TransactionRequest)
    case withdraw(TransactionRequest)
    case international(InternationalTransferRequest)

    var path: String {
        switch self {
        case .history:       return "/api/v1/transactions"
        case .transfer:      return "/api/v1/transactions/transfer"
        case .deposit:       return "/api/v1/transactions/deposit"
        case .withdraw:      return "/api/v1/transactions/withdraw"
        case .international: return "/api/v1/transactions/international"
        }
    }
    var method: HTTPMethod {
        self == .history ? .GET : .POST
    }
    var body: Encodable? {
        switch self {
        case .transfer(let r), .deposit(let r), .withdraw(let r): return r
        case .international(let r): return r
        default: return nil
        }
    }
}

extension TransactionEndpoint: Equatable {
    static func == (lhs: TransactionEndpoint, rhs: TransactionEndpoint) -> Bool {
        switch (lhs, rhs) {
        case (.history, .history): return true
        default: return false
        }
    }
}

// MARK: - OTP

enum OtpEndpoint: Endpoint {
    case generate

    var path: String { "/api/auth/otp/generate" }
    var method: HTTPMethod { .POST }
    var body: Encodable? { nil }
}

// MARK: - Scheduled Transactions

enum ScheduledTransactionEndpoint: Endpoint {
    case create(TransactionRequest)

    var path: String { "/api/v1/scheduled-transactions" }
    var method: HTTPMethod { .POST }
    var body: Encodable? {
        if case .create(let r) = self { return r }
        return nil
    }
}

// MARK: - Fixed Deposits

enum FixedDepositEndpoint: Endpoint {
    case create(FixedDepositCreateRequest)

    var path: String { "/api/v1/fixed-deposits/create" }
    var method: HTTPMethod { .POST }
    var body: Encodable? {
        if case .create(let r) = self { return r }
        return nil
    }
}

// MARK: - Statements

enum StatementEndpoint: Endpoint {
    case pdf(Int)   // accountId

    var path: String {
        switch self {
        case .pdf(let id): return "/api/v1/statements/\(id)/pdf"
        }
    }
    var method: HTTPMethod { .GET }
    var body: Encodable? { nil }
}

// MARK: - Notification Endpoints (Core Banking — device token registration)

struct DeviceTokenRequest: Encodable {
    let deviceToken: String
    let platform: String   // "IOS"
}

enum NotificationEndpoint: Endpoint {
    case registerDeviceToken(DeviceTokenRequest)

    var path: String { "/api/v1/notifications/device-token" }
    var method: HTTPMethod { .POST }
    var body: Encodable? {
        if case .registerDeviceToken(let r) = self { return r }
        return nil
    }
}

// MARK: - Notification Service Endpoints (titan-notifications-service)

/// GET /api/audit/account/{accountId}  — list notification history for a user
enum NotificationAuditEndpoint: Endpoint {
    case getByAccount(String)       // accountId as String (username or account id)

    var path: String {
        switch self {
        case .getByAccount(let id): return "/api/audit/account/\(id)"
        }
    }
    var method: HTTPMethod { .GET }
    var body: Encodable? { nil }
}

// MARK: - Send In-App Notification to a specific account (receiver)

struct SendNotificationRequest: Encodable {
    let accountId: String       // receiver's username
    let channel: String         // "IN_APP"
    let message: String
    let transactionId: String
    let urgent: Bool
}

enum SendNotificationEndpoint: Endpoint {
    case send(SendNotificationRequest)

    var path: String { "/api/notify" }
    var method: HTTPMethod { .POST }
    var body: Encodable? {
        if case .send(let r) = self { return r }
        return nil
    }
}

/// Notification preference model (read + write)
struct NotificationPreference: Codable {
    let userId: String
    var emailEnabled: Bool
    var smsEnabled: Bool
    var pushEnabled: Bool
    var marketingEnabled: Bool
    var locale: String
}

enum NotificationPreferenceEndpoint: Endpoint {
    case getPreference(String)                      // userId
    case updatePreference(NotificationPreference)   // full preference body

    var path: String {
        switch self {
        case .getPreference(let uid):  return "/api/preferences/\(uid)"
        case .updatePreference(let p): return "/api/preferences/\(p.userId)"
        }
    }
    var method: HTTPMethod {
        switch self {
        case .getPreference:  return .GET
        case .updatePreference: return .PUT
        }
    }
    var body: Encodable? {
        switch self {
        case .updatePreference(let p): return p
        default: return nil
        }
    }
}

// MARK: - Notification Audit Record (decoded from backend)

struct NotificationAuditRecord: Identifiable, Decodable {
    let id: Int
    let transactionId: String
    let accountId: String
    let channel: String        // "EMAIL", "SMS", "IN_APP"
    let recipient: String
    let message: String
    let status: String         // "SENT", "FAILED", "RATE_LIMITED", "DELIVERED"
    let provider: String?
    let errorMessage: String?
    let externalId: String?
    let attemptedAt: String    // normalized to ISO string in init
    let deliveredAt: String?
    let locale: String
    let urgent: Bool

    // ── Custom decoder: backend sends dates as [yyyy,MM,dd,HH,mm,ss,nano] array ──
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(Int.self,    forKey: .id)
        transactionId = try c.decode(String.self, forKey: .transactionId)
        accountId     = try c.decode(String.self, forKey: .accountId)
        channel       = try c.decode(String.self, forKey: .channel)
        recipient     = try c.decode(String.self, forKey: .recipient)
        message       = try c.decode(String.self, forKey: .message)
        status        = try c.decode(String.self, forKey: .status)
        provider      = try c.decodeIfPresent(String.self, forKey: .provider)
        errorMessage  = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        externalId    = try c.decodeIfPresent(String.self, forKey: .externalId)
        locale        = try c.decode(String.self, forKey: .locale)
        urgent        = try c.decode(Bool.self,   forKey: .urgent)

        // attemptedAt: try String first, fall back to [Int] array
        attemptedAt  = try Self.decodeDateField(c, forKey: .attemptedAt) ?? "Unknown"
        deliveredAt  = try Self.decodeDateFieldOptional(c, forKey: .deliveredAt)
    }

    /// Decodes a date field that may be a String OR a LocalDateTime array [y,M,d,H,m,s,nano]
    private static func decodeDateField(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String? {
        // Try String
        if let str = try? c.decodeIfPresent(String.self, forKey: key) {
            return str
        }
        // Try [Int] array  →  "2026-07-09 16:45:13"
        if let arr = try? c.decodeIfPresent([Int].self, forKey: key), arr.count >= 6 {
            return String(format: "%04d-%02d-%02d %02d:%02d:%02d",
                          arr[0], arr[1], arr[2], arr[3], arr[4], arr[5])
        }
        return nil
    }

    private static func decodeDateFieldOptional(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> String? {
        return try decodeDateField(c, forKey: key)
    }

    enum CodingKeys: String, CodingKey {
        case id, transactionId, accountId, channel, recipient, message
        case status, provider, errorMessage, externalId
        case attemptedAt, deliveredAt, locale, urgent
    }
}

// MARK: - Loan Endpoints  (routed through gateway → titan-loans-service:8085)
//
// Gateway routes /api/v1/loans/** → titan-loans-service:8085.
// Use APIClient.loanRequest() — it targets the gateway like every other call.

enum LoanEndpoint: Endpoint {
    case applyLoan(LoanRequest)
    case approveLoan(Int)
    case rejectLoan(Int)
    case getMyLoans
    case getLoanById(Int)
    case getByAccount(Int)
    case getRepaymentSchedule(Int)

    var path: String {
        switch self {
        case .applyLoan:                    return "/api/v1/loans/apply"
        case .approveLoan(let id):          return "/api/v1/loans/\(id)/approve"
        case .rejectLoan(let id):           return "/api/v1/loans/\(id)/reject"
        case .getMyLoans:                   return "/api/v1/loans/my"
        case .getLoanById(let id):          return "/api/v1/loans/\(id)"
        case .getByAccount(let accountId):  return "/api/v1/loans/account/\(accountId)"
        case .getRepaymentSchedule(let id): return "/api/v1/loans/\(id)/repayments"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .applyLoan:                return .POST
        case .approveLoan, .rejectLoan: return .PUT
        default:                        return .GET
        }
    }

    var body: Encodable? {
        switch self {
        case .applyLoan(let r): return r
        default:                return nil
        }
    }
}

// MARK: - QR Payment Endpoints

enum QrEndpoint: Endpoint {
    case generate(GenerateQrRequest)
    case pay(PayByQrRequest)
    case cancel(String)           // qrCode token
    case history(String)          // accountNumber
    /// GET /api/v1/qr/account/{accountNumber}
    /// Returns the persistent account QR (auto-creates one if none exists).
    case accountQr(String)        // accountNumber

    var path: String {
        switch self {
        case .generate:              return "/api/v1/qr/generate"
        case .pay:                   return "/api/v1/qr/pay"
        case .cancel(let code):      return "/api/v1/qr/cancel/\(code)"
        case .history(let acct):     return "/api/v1/qr/history/\(acct)"
        case .accountQr(let acct):   return "/api/v1/qr/account/\(acct)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .generate, .pay: return .POST
        case .cancel:         return .DELETE
        case .history, .accountQr: return .GET
        }
    }

    var body: Encodable? {
        switch self {
        case .generate(let r): return r
        case .pay(let r):      return r
        default:               return nil
        }
    }
}

// MARK: - ATM Cardless Withdrawal Endpoints

enum AtmEndpoint: Endpoint {
    case generate(AtmGenerateRequest)
    case redeem(AtmRedeemRequest)
    case cancel(String)     // 12-digit code
    case status(String)     // 12-digit code

    var path: String {
        switch self {
        case .generate:            return "/api/v1/atm/generate"
        case .redeem:              return "/api/v1/atm/redeem"
        case .cancel(let code):    return "/api/v1/atm/cancel/\(code)"
        case .status(let code):    return "/api/v1/atm/status/\(code)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .generate, .redeem: return .POST
        case .cancel:            return .DELETE
        case .status:            return .GET
        }
    }

    var body: Encodable? {
        switch self {
        case .generate(let r): return r
        case .redeem(let r):   return r
        default:               return nil
        }
    }
}

// MARK: - Promotion Endpoints (routed through gateway → titan-promotions-service:8083)

struct DepositPromotionApplyRequest: Encodable {
    let transactionId: String
    let type: String
    let amount: Double
    let currency: String
    let correlationId: String?
    let username: String?
    let targetAccountNumber: String?
    let metadata: [String: String]?
}

enum PromotionEndpoint: Endpoint {
    case applyDepositBonus(DepositPromotionApplyRequest)
    case depositCampaignStatus
    /// POST /api/quests/start?accountId=
    case startQuest(accountId: Int)
    case questProgress(String)
    case questStatus(String)
    /// POST /api/referrals/add?referrerId=&referredAccountId=
    case addReferral(referrerId: Int, referredAccountId: Int)
    case createMerchantCampaign(MerchantCampaignCreateRequest)
    /// GET /api/merchant/campaigns?tenantId=
    case listMerchantCampaigns(tenantId: String)
    case shadowRuleCost(String)
    case createCampaign
    case pauseCampaign(Int)
    case revokeCampaign(Int)
    case updateCampaign(Int)
    case listCampaigns

    var path: String {
        switch self {
        case .applyDepositBonus:       return "/promotions/deposit/apply"
        case .depositCampaignStatus:   return "/promotions/deposit/status"
        case .startQuest:              return "/api/quests/start"
        case .questProgress(let id):   return "/api/quests/\(id)/progress"
        case .questStatus(let id):     return "/api/quests/\(id)/status"
        case .addReferral:             return "/api/referrals/add"
        case .createMerchantCampaign:  return "/api/merchant/campaigns"
        case .listMerchantCampaigns:   return "/api/merchant/campaigns"
        case .shadowRuleCost(let id):  return "/api/shadow/rules/\(id)/cost"
        case .createCampaign:          return "/admin/campaigns"
        case .pauseCampaign(let id):   return "/admin/campaigns/\(id)/pause"
        case .revokeCampaign(let id):  return "/admin/campaigns/\(id)/revoke"
        case .updateCampaign(let id):  return "/admin/campaigns/\(id)"
        case .listCampaigns:           return "/admin/campaigns"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .depositCampaignStatus, .questStatus, .listMerchantCampaigns,
             .shadowRuleCost, .listCampaigns:
            return .GET
        case .pauseCampaign, .revokeCampaign, .updateCampaign:
            return .PUT
        default:
            return .POST
        }
    }

    var body: Encodable? {
        switch self {
        case .applyDepositBonus(let r): return r
        case .createMerchantCampaign(let r): return r
        default: return nil
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .startQuest(let accountId):
            return [URLQueryItem(name: "accountId", value: "\(accountId)")]
        case .addReferral(let referrerId, let referredAccountId):
            return [
                URLQueryItem(name: "referrerId", value: "\(referrerId)"),
                URLQueryItem(name: "referredAccountId", value: "\(referredAccountId)")
            ]
        case .listMerchantCampaigns(let tenantId):
            return [URLQueryItem(name: "tenantId", value: tenantId)]
        default:
            return nil
        }
    }
}

// MARK: - Extended Notification Service Endpoints

enum NotificationServiceEndpoint: Endpoint {
    case notifyTransaction
    case notifyHealth
    case auditByUser(String)
    case auditByTransaction(String)
    case auditByAccount(String)
    case twilioStatusWebhook
    case sendgridEventsWebhook
    case inboundTwilioSms
    case inboundWhatsapp
    case chaosBlackoutStart
    case chaosBlackoutStop
    case chaosBlackoutStatus

    var path: String {
        switch self {
        case .notifyTransaction:       return "/api/notify/transaction"
        case .notifyHealth:            return "/api/notify/health"
        case .auditByUser(let u):      return "/api/audit/user/\(u)"
        case .auditByTransaction(let t): return "/api/audit/transaction/\(t)"
        case .auditByAccount(let a):   return "/api/audit/account/\(a)"
        case .twilioStatusWebhook:     return "/api/webhooks/twilio/status"
        case .sendgridEventsWebhook:   return "/api/webhooks/sendgrid/events"
        case .inboundTwilioSms:        return "/webhooks/twilio/sms"
        case .inboundWhatsapp:         return "/webhooks/whatsapp"
        case .chaosBlackoutStart:      return "/chaos/blackout/start"
        case .chaosBlackoutStop:       return "/chaos/blackout/stop"
        case .chaosBlackoutStatus:     return "/chaos/blackout/status"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .notifyHealth, .auditByUser, .auditByTransaction, .auditByAccount, .chaosBlackoutStatus:
            return .GET
        default:
            return .POST
        }
    }

    var body: Encodable? { nil }
}