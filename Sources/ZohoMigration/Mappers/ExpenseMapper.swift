import Foundation

// MARK: - Expense Mapper (FBExpense → ZBExpense)

struct ExpenseMapper {

    static func map(
        _ expense: FBExpense,
        accountId: String,
        vendorId: String?,
        customerId: String?,
        paidThroughAccountId: String?,
        taxId: String?
    ) -> ZBExpense {
        var zbExpense = ZBExpense(
            accountId: accountId,
            date: expense.expenseDate,
            amount: expense.amountValue
        )

        zbExpense.description = expense.notes
        zbExpense.vendorId = vendorId
        zbExpense.customerId = customerId
        zbExpense.paidThroughAccountId = paidThroughAccountId
        zbExpense.taxId = taxId
        zbExpense.isBillable = expense.billable
        zbExpense.referenceNumber = expense.transactionId

        return zbExpense
    }
}
