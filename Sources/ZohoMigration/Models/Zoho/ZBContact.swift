import Foundation

// MARK: - Zoho Contact Person

struct ZBContactPerson: Codable {
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var mobile: String?
    var isPrimaryContact: Bool?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case mobile
        case isPrimaryContact = "is_primary_contact"
    }
}

// MARK: - Zoho Address

struct ZBAddress: Codable {
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var country: String?

    var isEmpty: Bool {
        return (address ?? "").isEmpty &&
               (city ?? "").isEmpty &&
               (state ?? "").isEmpty &&
               (zip ?? "").isEmpty &&
               (country ?? "").isEmpty
    }
}

// MARK: - Zoho Contact (Customer or Vendor)

struct ZBContact: Codable {
    var contactId: String?
    var contactName: String
    var companyName: String?
    var contactType: String // "customer" or "vendor"
    var contactPersons: [ZBContactPerson]?
    var billingAddress: ZBAddress?
    var shippingAddress: ZBAddress?
    var currencyCode: String?
    var notes: String?
    var taxId: String?
    var website: String?

    enum CodingKeys: String, CodingKey {
        case contactId = "contact_id"
        case contactName = "contact_name"
        case companyName = "company_name"
        case contactType = "contact_type"
        case contactPersons = "contact_persons"
        case billingAddress = "billing_address"
        case shippingAddress = "shipping_address"
        case currencyCode = "currency_code"
        case notes
        case taxId = "tax_id"
        case website
    }
}

// MARK: - Zoho API Response Structures

struct ZBContactResponse: Codable {
    let code: Int
    let message: String
    let contact: ZBContact?
}

struct ZBContactsListResponse: Codable {
    let code: Int
    let message: String
    let contacts: [ZBContact]?
}
