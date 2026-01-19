import Foundation

// MARK: - Payment Mapper (FBPayment → ZBPayment)

struct PaymentMapper {

    static func map(
        _ payment: FBPayment,
        customerId: String,
        invoiceId: String?,
        depositAccountId: String?
    ) -> ZBPayment {
        var zbPayment = ZBPayment(
            customerId: customerId,
            date: payment.date ?? {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: Date())
            }(),
            amount: payment.amountValue
        )

        // Link to invoice if available
        if let invId = invoiceId {
            let invoiceApplication = ZBPaymentInvoice(
                invoiceId: invId,
                amountApplied: payment.amountValue
            )
            zbPayment.invoices = [invoiceApplication]
        }

        zbPayment.paymentMode = payment.paymentMode
        zbPayment.referenceNumber = payment.referenceNumber
        zbPayment.description = payment.note
        zbPayment.accountId = depositAccountId

        return zbPayment
    }
}
