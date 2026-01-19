import Foundation

// MARK: - FreshBooks Client (Customer)

struct FBClient: Codable {
    let id: Int
    let organization: String?
    let fname: String?
    let lname: String?
    let email: String?
    let busPhone: String?
    let homePhone: String?
    let mobPhone: String?

    // Billing address
    let pStreet: String?
    let pStreet2: String?
    let pCity: String?
    let pProvince: String?
    let pCode: String?
    let pCountry: String?

    // Shipping address
    let sStreet: String?
    let sStreet2: String?
    let sCity: String?
    let sProvince: String?
    let sCode: String?
    let sCountry: String?

    let currencyCode: String?
    let note: String?
    let vatNumber: String?
    let visState: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case organization
        case fname
        case lname
        case email
        case busPhone = "bus_phone"
        case homePhone = "home_phone"
        case mobPhone = "mob_phone"
        case pStreet = "p_street"
        case pStreet2 = "p_street2"
        case pCity = "p_city"
        case pProvince = "p_province"
        case pCode = "p_code"
        case pCountry = "p_country"
        case sStreet = "s_street"
        case sStreet2 = "s_street2"
        case sCity = "s_city"
        case sProvince = "s_province"
        case sCode = "s_code"
        case sCountry = "s_country"
        case currencyCode = "currency_code"
        case note
        case vatNumber = "vat_number"
        case visState = "vis_state"
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var displayName: String {
        if let org = organization, !org.isEmpty {
            return org
        }
        let first = fname ?? ""
        let last = lname ?? ""
        let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        if !fullName.isEmpty {
            return fullName
        }
        return "Unknown Client \(id)"
    }
}

// MARK: - FreshBooks API Response Structures

struct FBClientsResponse: Codable {
    let response: FBClientsResponseInner
}

struct FBClientsResponseInner: Codable {
    let result: FBClientsResult
}

struct FBClientsResult: Codable {
    let clients: [FBClient]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case clients
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
