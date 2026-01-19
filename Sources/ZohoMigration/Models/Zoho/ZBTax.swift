import Foundation

// MARK: - Zoho Tax

struct ZBTax: Codable {
    var taxId: String?
    var taxName: String?
    var taxPercentage: Double?
    var taxType: String?
    var isDefaultTax: Bool?

    enum CodingKeys: String, CodingKey {
        case taxId = "tax_id"
        case taxName = "tax_name"
        case taxPercentage = "tax_percentage"
        case taxType = "tax_type"
        case isDefaultTax = "is_default_tax"
    }
}

// MARK: - Zoho Tax Exemption

struct ZBTaxExemption: Codable {
    var taxExemptionId: String?
    var taxExemptionCode: String?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case taxExemptionId = "tax_exemption_id"
        case taxExemptionCode = "tax_exemption_code"
        case description
    }
}

// MARK: - Zoho API Response Structures

struct ZBTaxesResponse: Codable {
    let code: Int
    let message: String
    let taxes: [ZBTax]?
}

struct ZBTaxExemptionsResponse: Codable {
    let code: Int
    let message: String
    let taxExemptions: [ZBTaxExemption]?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case taxExemptions = "tax_exemptions"
    }
}
