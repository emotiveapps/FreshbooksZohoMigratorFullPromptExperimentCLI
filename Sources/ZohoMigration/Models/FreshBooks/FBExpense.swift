import Foundation

// MARK: - FreshBooks Expense Attachment

struct FBExpenseAttachment: Codable {
    let attachmentid: Int?
    let id: Int?
    let jwt: String?
    let mediaType: String?
    let filename: String?

    enum CodingKeys: String, CodingKey {
        case attachmentid
        case id
        case jwt
        case mediaType = "media_type"
        case filename
    }

    var attachmentId: Int {
        return attachmentid ?? id ?? 0
    }
}

// MARK: - FreshBooks Expense

struct FBExpense: Codable {
    let id: Int
    let expenseId: Int?
    let categoryId: Int?
    let date: String?
    let amount: FBMoney?
    let notes: String?
    let vendor: String?
    let clientId: Int?
    let accountName: String?
    let taxName1: String?
    let taxAmount1: FBMoney?
    let taxPercent1: String?
    let billable: Bool?
    let transactionId: String?
    let visState: Int?
    let attachment: FBExpenseAttachment?
    let hasReceipt: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expenseid"
        case categoryId = "categoryid"
        case date
        case amount
        case notes
        case vendor
        case clientId = "clientid"
        case accountName = "account_name"
        case taxName1 = "tax_name1"
        case taxAmount1 = "tax_amount1"
        case taxPercent1 = "tax_percent1"
        case billable
        case transactionId = "transactionid"
        case visState = "vis_state"
        case attachment
        case hasReceipt = "has_receipt"
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var expenseDate: String {
        return date ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()
    }

    var amountValue: Double {
        return amount?.doubleValue ?? 0
    }
}

// MARK: - FreshBooks API Response Structures

struct FBExpensesResponse: Codable {
    let response: FBExpensesResponseInner
}

struct FBExpensesResponseInner: Codable {
    let result: FBExpensesResult
}

struct FBExpensesResult: Codable {
    let expenses: [FBExpense]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case expenses
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
