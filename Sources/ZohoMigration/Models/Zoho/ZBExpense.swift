import Foundation

// MARK: - Zoho Expense

struct ZBExpense: Codable {
    var expenseId: String?
    var accountId: String
    var date: String
    var amount: Double
    var description: String?
    var vendorId: String?
    var customerId: String?
    var paidThroughAccountId: String?
    var taxId: String?
    var isBillable: Bool?
    var referenceNumber: String?

    enum CodingKeys: String, CodingKey {
        case expenseId = "expense_id"
        case accountId = "account_id"
        case date
        case amount
        case description
        case vendorId = "vendor_id"
        case customerId = "customer_id"
        case paidThroughAccountId = "paid_through_account_id"
        case taxId = "tax_id"
        case isBillable = "is_billable"
        case referenceNumber = "reference_number"
    }
}

// MARK: - Zoho API Response Structures

struct ZBExpenseResponse: Codable {
    let code: Int
    let message: String
    let expense: ZBExpense?
}

struct ZBExpensesListResponse: Codable {
    let code: Int
    let message: String
    let expenses: [ZBExpense]?
}
