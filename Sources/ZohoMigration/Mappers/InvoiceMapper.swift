import Foundation

// MARK: - Invoice Mapper (FBInvoice → ZBInvoice)

struct InvoiceMapper {

    static func map(
        _ invoice: FBInvoice,
        customerId: String,
        taxLookup: @escaping (String?) -> String?,
        taxExemptionId: String?
    ) -> ZBInvoice {
        // Map line items
        let lineItems: [ZBInvoiceLineItem] = (invoice.lines ?? []).map { line in
            var zbLine = ZBInvoiceLineItem(
                name: line.name ?? "Item",
                rate: line.rate,
                quantity: line.quantity
            )
            zbLine.description = line.description

            // Handle tax
            if line.hasTax, let taxName = line.taxName1 {
                zbLine.taxId = taxLookup(taxName)
            } else if let exemptionId = taxExemptionId {
                zbLine.taxExemptionId = exemptionId
            }

            return zbLine
        }

        // Build the invoice
        var zbInvoice = ZBInvoice(customerId: customerId)
        zbInvoice.invoiceNumber = invoice.invoiceNumber
        zbInvoice.referenceNumber = invoice.poNumber
        zbInvoice.date = invoice.createDate
        zbInvoice.dueDate = invoice.dueDate
        zbInvoice.currencyCode = invoice.currencyCode
        zbInvoice.notes = invoice.notes
        zbInvoice.isInclusiveTax = false
        zbInvoice.lineItems = lineItems.isEmpty ? nil : lineItems

        return zbInvoice
    }
}
