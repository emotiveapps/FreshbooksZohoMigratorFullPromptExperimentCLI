import Foundation

// MARK: - FreshBooks Payment

struct FBPayment: Codable {
    let id: Int
    let paymentId: Int?
    let clientId: Int?
    let date: String?
    let amount: FBMoney?
    let invoiceId: Int?
    let gateway: String?
    let type: String?
    let transactionId: String?
    let orderId: String?
    let note: String?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case paymentId = "paymentid"
        case clientId = "clientid"
        case date
        case amount
        case invoiceId = "invoiceid"
        case gateway
        case type
        case transactionId = "transactionid"
        case orderId = "orderid"
        case note
        case visState = "vis_state"
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var amountValue: Double {
        return amount?.doubleValue ?? 0
    }

    var paymentMode: String {
        let source = (gateway ?? type ?? "").lowercased()

        if source.contains("stripe") || source.contains("square") || source.contains("2checkout") {
            return "credit_card"
        }
        if source.contains("paypal") {
            return "paypal"
        }
        if source.contains("wechat") || source.contains("ach") || source.contains("bank") || source.contains("transfer") {
            return "bank_transfer"
        }
        if source.contains("check") || source.contains("cheque") {
            return "check"
        }
        if source.contains("cash") {
            return "cash"
        }
        return "other"
    }

    var referenceNumber: String? {
        return transactionId ?? orderId
    }
}

// MARK: - FreshBooks API Response Structures

struct FBPaymentsResponse: Codable {
    let response: FBPaymentsResponseInner
}

struct FBPaymentsResponseInner: Codable {
    let result: FBPaymentsResult
}

struct FBPaymentsResult: Codable {
    let payments: [FBPayment]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case payments
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
