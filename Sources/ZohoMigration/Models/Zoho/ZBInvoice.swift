import Foundation

// MARK: - Zoho Invoice Line Item

struct ZBInvoiceLineItem: Codable {
    var name: String
    var description: String?
    var rate: Double
    var quantity: Double
    var taxId: String?
    var taxExemptionId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case rate
        case quantity
        case taxId = "tax_id"
        case taxExemptionId = "tax_exemption_id"
    }
}

// MARK: - Zoho Invoice

struct ZBInvoice: Codable {
    var invoiceId: String?
    var invoiceNumber: String?
    var customerId: String
    var referenceNumber: String?
    var date: String?
    var dueDate: String?
    var currencyCode: String?
    var notes: String?
    var isInclusiveTax: Bool?
    var lineItems: [ZBInvoiceLineItem]?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case invoiceId = "invoice_id"
        case invoiceNumber = "invoice_number"
        case customerId = "customer_id"
        case referenceNumber = "reference_number"
        case date
        case dueDate = "due_date"
        case currencyCode = "currency_code"
        case notes
        case isInclusiveTax = "is_inclusive_tax"
        case lineItems = "line_items"
        case status
    }
}

// MARK: - Zoho API Response Structures

struct ZBInvoiceResponse: Codable {
    let code: Int
    let message: String
    let invoice: ZBInvoice?
}

struct ZBInvoicesListResponse: Codable {
    let code: Int
    let message: String
    let invoices: [ZBInvoice]?
}
