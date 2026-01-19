import Foundation

// MARK: - Zoho Payment Invoice Application

struct ZBPaymentInvoice: Codable {
    var invoiceId: String
    var amountApplied: Double

    enum CodingKeys: String, CodingKey {
        case invoiceId = "invoice_id"
        case amountApplied = "amount_applied"
    }
}

// MARK: - Zoho Customer Payment

struct ZBPayment: Codable {
    var paymentId: String?
    var customerId: String
    var date: String
    var amount: Double
    var invoices: [ZBPaymentInvoice]?
    var paymentMode: String?
    var referenceNumber: String?
    var description: String?
    var accountId: String?

    enum CodingKeys: String, CodingKey {
        case paymentId = "payment_id"
        case customerId = "customer_id"
        case date
        case amount
        case invoices
        case paymentMode = "payment_mode"
        case referenceNumber = "reference_number"
        case description
        case accountId = "account_id"
    }
}

// MARK: - Zoho API Response Structures

struct ZBPaymentResponse: Codable {
    let code: Int
    let message: String
    let payment: ZBPayment?
}

struct ZBPaymentsListResponse: Codable {
    let code: Int
    let message: String
    let customerpayments: [ZBPayment]?
}
