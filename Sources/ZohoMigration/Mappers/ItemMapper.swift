import Foundation

// MARK: - Item Mapper (FBItem → ZBItem)

struct ItemMapper {

    static func map(_ item: FBItem) -> ZBItem {
        var zbItem = ZBItem(name: item.displayName)
        zbItem.description = item.description
        zbItem.rate = item.rate
        zbItem.sku = item.sku
        zbItem.productType = "service" // Default to service

        return zbItem
    }
}
