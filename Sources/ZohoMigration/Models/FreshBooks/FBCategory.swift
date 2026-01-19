import Foundation

// MARK: - FreshBooks Category (Expense Category)

struct FBCategory: Codable {
    let id: Int
    let categoryId: Int?
    let categoryName: String?
    let parentId: Int?
    let isCogs: Bool?
    let isEditable: Bool?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "categoryid"
        case categoryName = "category_name"
        case parentId = "parentid"
        case isCogs = "is_cogs"
        case isEditable = "is_editable"
        case visState = "vis_state"
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var displayName: String {
        return categoryName ?? "Category \(id)"
    }

    var categoryIdentifier: Int {
        return categoryId ?? id
    }
}

// MARK: - FreshBooks API Response Structures

struct FBCategoriesResponse: Codable {
    let response: FBCategoriesResponseInner
}

struct FBCategoriesResponseInner: Codable {
    let result: FBCategoriesResult
}

struct FBCategoriesResult: Codable {
    let categories: [FBCategory]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case categories
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
