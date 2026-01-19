import Foundation

// MARK: - FreshBooks Vendor

struct FBVendor: Codable {
    let vendorId: Int
    let vendorName: String?
    let primaryContactEmail: String?
    let primaryContactFirstName: String?
    let primaryContactLastName: String?
    let phone: String?
    let street: String?
    let street2: String?
    let city: String?
    let province: String?
    let postalCode: String?
    let country: String?
    let currencyCode: String?
    let note: String?
    let website: String?
    let taxId: String?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case vendorId = "vendorid"
        case vendorName = "vendor_name"
        case primaryContactEmail = "primary_contact_email"
        case primaryContactFirstName = "primary_contact_first_name"
        case primaryContactLastName = "primary_contact_last_name"
        case phone
        case street
        case street2
        case city
        case province
        case postalCode = "postal_code"
        case country
        case currencyCode = "currency_code"
        case note
        case website
        case taxId = "tax_id"
        case visState = "vis_state"
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var displayName: String {
        if let name = vendorName, !name.isEmpty {
            return name
        }
        return "Vendor \(vendorId)"
    }
}

// MARK: - FreshBooks API Response Structures

struct FBVendorsResponse: Codable {
    let response: FBVendorsResponseInner
}

struct FBVendorsResponseInner: Codable {
    let result: FBVendorsResult
}

struct FBVendorsResult: Codable {
    let vendors: [FBVendor]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case vendors
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
