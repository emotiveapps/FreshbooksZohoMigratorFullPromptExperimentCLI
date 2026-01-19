import Foundation

// MARK: - FreshBooks Money Amount

struct FBMoney: Codable {
    let amount: String?
    let code: String?

    var doubleValue: Double {
        guard let amountStr = amount else { return 0 }
        return Double(amountStr) ?? 0
    }
}

// MARK: - FreshBooks Invoice Line Item

struct FBInvoiceLine: Codable {
    let lineId: Int?
    let name: String?
    let description: String?
    let unitCost: FBMoney?
    let qty: String?
    let amount: FBMoney?
    let taxName1: String?
    let taxAmount1: String?
    let taxName2: String?
    let taxAmount2: String?

    enum CodingKeys: String, CodingKey {
        case lineId = "lineid"
        case name
        case description
        case unitCost = "unit_cost"
        case qty
        case amount
        case taxName1 = "tax_name1"
        case taxAmount1 = "tax_amount1"
        case taxName2 = "tax_name2"
        case taxAmount2 = "tax_amount2"
    }

    var quantity: Double {
        guard let qtyStr = qty else { return 1 }
        return Double(qtyStr) ?? 1
    }

    var rate: Double {
        return unitCost?.doubleValue ?? 0
    }

    var hasTax: Bool {
        if let taxAmt = taxAmount1, let val = Double(taxAmt), val > 0 {
            return true
        }
        return false
    }
}

// MARK: - FreshBooks Invoice

struct FBInvoice: Codable {
    let id: Int
    let invoiceId: Int?
    let invoiceNumber: String?
    let customerId: Int?
    let poNumber: String?
    let createDate: String?
    let dueDate: String?
    let currencyCode: String?
    let notes: String?
    let lines: [FBInvoiceLine]?
    let status: Int?
    let v3Status: String?
    let visState: Int?
    let amount: FBMoney?
    let outstanding: FBMoney?
    let paid: FBMoney?

    enum CodingKeys: String, CodingKey {
        case id
        case invoiceId = "invoiceid"
        case invoiceNumber = "invoice_number"
        case customerId = "customerid"
        case poNumber = "po_number"
        case createDate = "create_date"
        case dueDate = "due_date"
        case currencyCode = "currency_code"
        case notes
        case lines
        case status
        case v3Status = "v3_status"
        case visState = "vis_state"
        case amount
        case outstanding
        case paid
    }

    var isActive: Bool {
        visState == nil || visState == 0
    }

    var shouldMarkAsSent: Bool {
        // If it's not a draft, mark as sent
        if let v3 = v3Status, v3.lowercased() != "draft" {
            return true
        }
        // Status codes: 1=draft, 2=sent, etc.
        if let s = status, s >= 2 {
            return true
        }
        return false
    }
}

// MARK: - FreshBooks API Response Structures

struct FBInvoicesResponse: Codable {
    let response: FBInvoicesResponseInner
}

struct FBInvoicesResponseInner: Codable {
    let result: FBInvoicesResult
}

struct FBInvoicesResult: Codable {
    let invoices: [FBInvoice]
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case invoices
        case page
        case pages
        case perPage = "per_page"
        case total
    }
}
