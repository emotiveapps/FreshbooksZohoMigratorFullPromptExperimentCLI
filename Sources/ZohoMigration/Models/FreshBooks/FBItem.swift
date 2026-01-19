import Foundation

// MARK: - FreshBooks Item (Product/Service)

struct FBItem: Codable {
    let id: Int
    let itemId: Int?
    let name: String?
    let description: String?
    let unitCost: FBMoney?
    let qty: String?
    let sku: String?
    let inventory: String?
    let tax1: Int?
    let tax2: Int?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "itemid"
        case name
        case description
        case unitCost = "unit_cost"
        case qty
        case sku
        case inventory
        case tax1
        case tax2
        case visState = "vis_state"
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var displayName: String {
        return name ?? "Item \(id)"
    }

    var rate: Double {
        return unitCost?.doubleValue ?? 0
    }
}

// MARK: - FreshBooks API Response Structures

struct FBItemsResponse: Codable {
    let response: FBItemsResponseInner
}

struct FBItemsResponseInner: Codable {
    let result: FBItemsResult
}

struct FBItemsResult: Codable {
    let items: [FBItem]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
