import Foundation

// MARK: - Zoho Item (Product/Service)

struct ZBItem: Codable {
    var itemId: String?
    var name: String
    var description: String?
    var rate: Double?
    var sku: String?
    var productType: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case name
        case description
        case rate
        case sku
        case productType = "product_type"
    }
}

// MARK: - Zoho API Response Structures

struct ZBItemResponse: Codable {
    let code: Int
    let message: String
    let item: ZBItem?
}

struct ZBItemsListResponse: Codable {
    let code: Int
    let message: String
    let items: [ZBItem]?
}
