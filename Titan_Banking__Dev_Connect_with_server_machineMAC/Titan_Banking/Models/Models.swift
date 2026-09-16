import Foundation

// MARK: - User Profile
struct UserProfile: Decodable {
    let id: Int
    let username: String
    let email: String?
    let firstName: String?
    let lastName: String?
    var fullName: String { "\(firstName ?? "") \(lastName ?? "")".trimmingCharacters(in: .whitespaces) }
}

// MARK: - Auth

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let firstName: String
    let lastName: String
    let username: String
    let email: String
    let password: String
    let pin: String
}

struct AuthResponse: Decodable {
    let token: String
    let id: Int
}

// MARK: - Account

struct AccountModel: Decodable, Identifiable, Equatable {
    let id: Int
    let accountNumber: String
    let accountType: String
    let currency: String
    let balance: Double
    let status: String
}

struct CreateAccountRequest: Encodable {
    let accountType: String   // SAVINGS | CHECKING
    let currency: String      // USD | KHR
}

// MARK: - Transaction

struct TransactionRequest: Encodable {
    let fromAccountNumber: String?
    let toAccountNumber: String?
    let amount: Double
    let note: String?
    let pin: String?
    /// Unique key to prevent duplicate submissions (UUID generated per request)
    let idempotencyKey: String

    init(fromAccountNumber: String?, toAccountNumber: String?,
         amount: Double, note: String?, pin: String?) {
        self.fromAccountNumber = fromAccountNumber
        self.toAccountNumber = toAccountNumber
        self.amount = amount
        self.note = note
        self.pin = pin
        self.idempotencyKey = UUID().uuidString
    }
}

struct TransactionResponse: Decodable, Identifiable, Equatable {
    let id: Int
    let type: String
    let amount: Double
    let fromAccountNumber: String?
    let toAccountNumber: String?
    let status: String
    let note: String?
    let timestamp: Date?
    let currency: String
    let fee: Double
    /// Maps to idempotencyKey returned by backend (used as reference number)
    let referenceNumber: String?

    enum CodingKeys: String, CodingKey {
        case id, type, amount, fromAccountNumber, toAccountNumber
        case status, note, timestamp, currency, fee
        // backend sends idempotencyKey — map it as referenceNumber for display
        case referenceNumber = "idempotencyKey"
    }
}

// MARK: - Loan

/// POST /api/v1/loans/apply  →  titan-loans-service:8085
/// interestRate is fixed at 5%/month server-side; we omit it from request.
struct LoanRequest: Encodable {
    let accountId: Int
    let accountNumber: String
    let amount: Double
    let termMonths: Int
    let note: String?
}

/// Response from titan-loans-service for a single loan
struct LoanModel: Decodable, Identifiable {
    let id: Int
    let accountId: Int
    let accountNumber: String
    let username: String?
    let amount: Double
    /// Monthly interest rate — always 0.05 (5% per month)
    let interestRate: Double
    let termMonths: Int
    /// Pre-calculated by server: monthly amortization payment
    let monthlyPayment: Double?
    /// One-time 4% processing fee charged on approval
    let processingFee: Double?
    let status: String
    let note: String?
    let appliedAt: String?
    let approvedAt: String?
    let rejectedAt: String?
}

/// Response from PUT /api/v1/loans/{id}/approve
struct LoanApprovalResponse: Decodable {
    let message: String
    let loanId: Int
    let monthlyPayment: Double
    let processingFee: Double
    let totalRepayments: Int
}

/// One row in the amortization schedule from GET /api/v1/loans/{id}/repayments
struct LoanRepaymentModel: Decodable, Identifiable {
    let id: Int
    let loanId: Int
    let installmentNumber: Int
    let dueDate: String?
    let amount: Double
    let status: String      // PENDING | PAID
    let paidDate: String?
}

// MARK: - ATM Cardless Withdrawal

/// Request sent to POST /api/v1/atm/generate
struct AtmGenerateRequest: Encodable {
    let accountNumber: String
    let amount: Double
    let pin: String
}

/// Request sent to POST /api/v1/atm/redeem  (ATM terminal side — included for completeness)
struct AtmRedeemRequest: Encodable {
    let code: String
    let terminalId: String?
}

/// Unified response for all ATM endpoints
struct AtmCodeResponse: Decodable, Identifiable {
    let id: Int
    /// The 12-digit one-time code
    let code: String
    let accountNumber: String
    let amount: Double
    /// PENDING | USED | EXPIRED | CANCELLED
    let status: String
    let expiresAt: Date?
    let redeemedAt: Date?
    let createdAt: Date?
    /// Human-readable message from the server
    let message: String?
}

// MARK: - Promotions (titan-promotions-service)

/// GET /promotions/deposit/status
struct CampaignStatus: Decodable {
    let campaignCode: String?
    let found: Bool
    let dbStatus: String?
    let startDate: String?
    let endDate: String?
    let currentTime: String?
    let withinWindow: Bool
    let active: Bool
    let minDeposit: Double?
    let bonusAmount: Double?
    let quotaUsed: Int?
    let quotaLimit: Int?
    let message: String?
}

/// POST /promotions/deposit/apply
struct DepositBonusApplyResponse: Decodable {
    let transactionId: String?
    let depositAmount: Double?
    let applied: Bool
    let bonus: Double?
    let campaignCode: String?
    let message: String?
}

/// POST /api/quests/start → { questId, status }
struct QuestStartResponse: Decodable {
    let questId: String
    let status: String
}

/// POST /api/quests/{id}/progress → { success, currentState }
struct QuestProgressResponse: Decodable {
    let success: Bool
    let currentState: String
}

/// GET /api/quests/{id}/status → { questId, state }
struct QuestStatusResponse: Decodable {
    let questId: String
    let state: String
}

/// POST /api/referrals/add → { status, message }
struct ReferralAddResponse: Decodable {
    let status: String
    let message: String
}

/// POST /api/merchant/campaigns body (remainingBudget/active set server-side)
struct MerchantCampaignCreateRequest: Encodable {
    let tenantId: String
    let merchantName: String
    let merchantAccountId: Int
    let campaignName: String
    let totalBudget: Double
    let startDate: String
    let endDate: String
    let ruleExpression: String?
}

/// Merchant campaign from titan-promotions-service
struct MerchantCampaignModel: Decodable, Identifiable {
    let id: Int
    let tenantId: String
    let merchantName: String
    let merchantAccountId: Int
    let campaignName: String
    let totalBudget: Double
    let remainingBudget: Double?
    let startDate: String?
    let endDate: String?
    let ruleExpression: String?
    let active: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        tenantId = try c.decode(String.self, forKey: .tenantId)
        merchantName = try c.decode(String.self, forKey: .merchantName)
        merchantAccountId = try c.decode(Int.self, forKey: .merchantAccountId)
        campaignName = try c.decode(String.self, forKey: .campaignName)
        totalBudget = try Self.decodeDouble(c, forKey: .totalBudget) ?? 0
        remainingBudget = try Self.decodeDouble(c, forKey: .remainingBudget)
        startDate = try Self.decodeFlexibleDate(c, forKey: .startDate)
        endDate = try Self.decodeFlexibleDate(c, forKey: .endDate)
        ruleExpression = try c.decodeIfPresent(String.self, forKey: .ruleExpression)
        active = try c.decodeIfPresent(Bool.self, forKey: .active)
    }

    private static func decodeDouble(
        _ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        return nil
    }

    private static func decodeFlexibleDate(
        _ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let arr = try? c.decodeIfPresent([Int].self, forKey: key), arr.count >= 3 {
            let h = arr.count > 3 ? arr[3] : 0
            let m = arr.count > 4 ? arr[4] : 0
            let s = arr.count > 5 ? arr[5] : 0
            return String(format: "%04d-%02d-%02d %02d:%02d:%02d",
                          arr[0], arr[1], arr[2], h, m, s)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, tenantId, merchantName, merchantAccountId, campaignName
        case totalBudget, remainingBudget, startDate, endDate, ruleExpression, active
    }
}

// MARK: - OTP

struct OtpGenerateResponse: Decodable {
    let message: String?
    let status: String?
    let otp: String?   // only present for test usernames
    let error: String?
}

// MARK: - International Transfer

struct InternationalTransferRequest: Encodable {
    let fromAccountNumber: String
    let amount: Double
    let pin: String
    let note: String?
    let swiftCode: String
    let iban: String
    let idempotencyKey: String

    init(fromAccountNumber: String, amount: Double, pin: String,
         note: String?, swiftCode: String, iban: String) {
        self.fromAccountNumber = fromAccountNumber
        self.amount = amount
        self.pin = pin
        self.note = note
        self.swiftCode = swiftCode.uppercased()
        self.iban = iban.uppercased().replacingOccurrences(of: " ", with: "")
        self.idempotencyKey = UUID().uuidString
    }
}

// MARK: - Scheduled Transaction

struct ScheduledTransactionModel: Decodable, Identifiable {
    let id: Int
    let fromAccountId: Int?
    let toAccountNumber: String?
    let amount: Double
    let frequency: String?
    let status: String?
    let startDate: String?
    let scheduledDate: String?
    let createdAt: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        fromAccountId = try c.decodeIfPresent(Int.self, forKey: .fromAccountId)
        toAccountNumber = try c.decodeIfPresent(String.self, forKey: .toAccountNumber)
        amount = try Self.decodeDouble(c, forKey: .amount) ?? 0
        frequency = try c.decodeIfPresent(String.self, forKey: .frequency)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        startDate = try Self.decodeFlexibleDate(c, forKey: .startDate)
        scheduledDate = try Self.decodeFlexibleDate(c, forKey: .scheduledDate)
        createdAt = try Self.decodeFlexibleDate(c, forKey: .createdAt)
    }

    private static func decodeDouble(
        _ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        return nil
    }

    private static func decodeFlexibleDate(
        _ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let arr = try? c.decodeIfPresent([Int].self, forKey: key), arr.count >= 3 {
            let h = arr.count > 3 ? arr[3] : 0
            let m = arr.count > 4 ? arr[4] : 0
            let s = arr.count > 5 ? arr[5] : 0
            return String(format: "%04d-%02d-%02d %02d:%02d:%02d",
                          arr[0], arr[1], arr[2], h, m, s)
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id, fromAccountId, toAccountNumber, amount, frequency, status
        case startDate, scheduledDate, createdAt
    }
}

// MARK: - Fixed Deposit

struct FixedDepositCreateRequest: Encodable {
    let accountId: Int
    let amount: Double
    let termMonths: Int
}

struct FixedDepositModel: Decodable, Identifiable {
    let id: Int
    let accountId: Int
    let principalAmount: Double
    let maturityAmount: Double
    let termMonths: Int
    let interestRate: Double
    let status: String?
    let maturityDate: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        accountId = try c.decode(Int.self, forKey: .accountId)
        principalAmount = try c.decode(Double.self, forKey: .principalAmount)
        maturityAmount = try c.decode(Double.self, forKey: .maturityAmount)
        termMonths = try c.decode(Int.self, forKey: .termMonths)
        interestRate = try c.decode(Double.self, forKey: .interestRate)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        if let s = try? c.decodeIfPresent(String.self, forKey: .maturityDate) {
            maturityDate = s
        } else if let arr = try? c.decodeIfPresent([Int].self, forKey: .maturityDate),
                  arr.count >= 3 {
            maturityDate = String(format: "%04d-%02d-%02d", arr[0], arr[1], arr[2])
        } else {
            maturityDate = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, accountId, principalAmount, maturityAmount
        case termMonths, interestRate, status, maturityDate
    }
}