import Foundation

// MARK: - Generate QR Request
/// Payee calls this to create a QR code for receiving money.
struct GenerateQrRequest: Encodable {
    let payeeAccountNumber: String
    /// Fixed amount (nil = open-amount QR; payer can enter any amount)
    let amount: Double?
    let note: String?
    /// How many minutes until the QR expires (default 15 on server)
    let ttlMinutes: Int?
}

// MARK: - Pay by QR Request
/// Payer calls this after scanning a QR code.
struct PayByQrRequest: Encodable {
    let qrCode: String
    let payerAccountNumber: String
    /// Required only for open-amount QR codes
    let amount: Double?
    let pin: String
}

// MARK: - QR Payment Response
/// Returned by both generate and pay endpoints.
struct QrPaymentResponse: Decodable, Identifiable {
    let id: Int
    let qrCode: String
    /// Base64-encoded PNG — only present in the generateQr response
    let qrImageBase64: String?
    /// PENDING | SUCCESS | EXPIRED | CANCELLED
    let status: String
    let amount: Double?
    let currency: String?
    let payeeAccountNumber: String
    let payerAccountNumber: String?
    let note: String?
    let createdAt: Date?
    let expiresAt: Date?
    let paidAt: Date?
    let transactionId: Int?

    /// Explicit keys because the server uses `payeeAccount` / `payerAccount`
    /// but our Swift model uses the clearer `payeeAccountNumber` / `payerAccountNumber`.
    enum CodingKeys: String, CodingKey {
        case id
        case qrCode
        case qrImageBase64
        case status
        case amount
        case currency
        case payeeAccountNumber = "payeeAccount"
        case payerAccountNumber = "payerAccount"
        case note
        case createdAt
        case expiresAt
        case paidAt
        case transactionId
    }
}

// MARK: - Cancel QR Request
struct CancelQrRequest: Encodable {
    let qrCode: String
}
