import Foundation

// MARK: - Category Mapper (FBCategory → ZBAccount)

struct CategoryMapper {

    /// Direct mode mapping - simple 1:1 mapping
    static func map(_ category: FBCategory) -> ZBAccount {
        let accountType: String
        if category.isCogs == true {
            accountType = "cost_of_goods_sold"
        } else {
            accountType = "expense"
        }

        var account = ZBAccount(
            accountName: category.displayName,
            accountType: accountType
        )
        account.accountCode = "\(category.categoryIdentifier)"
        account.description = "Imported from FreshBooks"

        return account
    }

    /// Create account from hierarchy config
    static func mapFromConfig(
        name: String,
        accountType: String = "expense",
        parentAccountId: String? = nil
    ) -> ZBAccount {
        var account = ZBAccount(
            accountName: name,
            accountType: accountType
        )
        account.parentAccountId = parentAccountId
        account.description = "Imported from FreshBooks"
        return account
    }
}
