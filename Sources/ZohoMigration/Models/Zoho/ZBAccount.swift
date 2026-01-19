import Foundation

// MARK: - Zoho Chart of Account

struct ZBAccount: Codable {
    var accountId: String?
    var accountName: String
    var accountCode: String?
    var accountType: String
    var description: String?
    var parentAccountId: String?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case accountName = "account_name"
        case accountCode = "account_code"
        case accountType = "account_type"
        case description
        case parentAccountId = "parent_account_id"
        case isActive = "is_active"
    }
}

// MARK: - Zoho API Response Structures

struct ZBAccountResponse: Codable {
    let code: Int
    let message: String
    let chartofaccount: ZBAccount?
}

struct ZBAccountsListResponse: Codable {
    let code: Int
    let message: String
    let chartofaccounts: [ZBAccount]?
}
