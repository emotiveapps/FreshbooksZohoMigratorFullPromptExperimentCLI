import Foundation

// MARK: - Migration Statistics

struct MigrationStats {
    var succeeded: Int = 0
    var failed: Int = 0
    var skipped: Int = 0
    var errors: [(entity: String, error: String)] = []

    mutating func addSuccess() {
        succeeded += 1
    }

    mutating func addFailure(entity: String, error: String) {
        failed += 1
        if errors.count < 10 {
            errors.append((entity, error))
        }
    }

    mutating func addSkipped() {
        skipped += 1
    }

    func printSummary(entityType: String) {
        print("\(entityType): Succeeded: \(succeeded), Failed: \(failed), Skipped: \(skipped)")
        if !errors.isEmpty {
            print("First \(errors.count) errors:")
            for (entity, error) in errors {
                print("  - \(entity): \(error)")
            }
        }
    }
}

// MARK: - Migration Options

struct MigrationOptions {
    var dryRun: Bool = false
    var verbose: Bool = false
    var useConfigMapping: Bool = false
    var includeItems: Bool = false
    var includeAttachments: Bool = false
}

// MARK: - Migration Service

actor MigrationService {
    private let freshBooksAPI: FreshBooksAPI
    private let zohoAPI: ZohoAPI
    private let configManager: ConfigurationManager

    // ID Mappings (FreshBooks ID → Zoho ID)
    private var customerIdMapping: [Int: String] = [:]
    private var vendorIdMapping: [Int: String] = [:]
    private var accountIdMapping: [Int: String] = [:]
    private var invoiceIdMapping: [Int: String] = [:]
    private var itemIdMapping: [Int: String] = [:]

    // Caches
    private var vendorNameCache: [String: String] = [:] // name → zohoId
    private var accountNameCache: [String: String] = [:]
    private var taxNameCache: [String: String] = [:]
    private var serviceTaxExemptionId: String?

    // Options
    private var options: MigrationOptions = MigrationOptions()

    init(freshBooksAPI: FreshBooksAPI, zohoAPI: ZohoAPI, configManager: ConfigurationManager) {
        self.freshBooksAPI = freshBooksAPI
        self.zohoAPI = zohoAPI
        self.configManager = configManager
    }

    func setOptions(_ options: MigrationOptions) {
        self.options = options
    }

    // MARK: - Cache Initialization

    private func initializeCaches() async throws {
        // Load existing Zoho contacts (vendors) into cache
        let vendors = try await zohoAPI.fetchContacts(contactType: "vendor")
        for vendor in vendors {
            if let id = vendor.contactId {
                vendorNameCache[vendor.contactName.lowercased()] = id
            }
        }

        // Load existing Zoho accounts into cache
        let accounts = try await zohoAPI.fetchAccounts()
        for account in accounts {
            if let id = account.accountId {
                accountNameCache[account.accountName.lowercased()] = id
            }
        }

        // Load taxes into cache
        let taxes = try await zohoAPI.fetchTaxes()
        for tax in taxes {
            if let id = tax.taxId, let name = tax.taxName {
                taxNameCache[name.lowercased()] = id
            }
        }

        // Get service tax exemption
        if let exemption = try await zohoAPI.getServiceTaxExemption() {
            serviceTaxExemptionId = exemption.taxExemptionId
        }

        if options.verbose {
            print("Loaded caches: \(vendorNameCache.count) vendors, \(accountNameCache.count) accounts, \(taxNameCache.count) taxes")
        }
    }

    // MARK: - Migrate All

    func migrateAll() async throws {
        try await initializeCaches()

        print("\n=== Starting Migration ===\n")

        // 1. Categories first (needed for expenses)
        try await migrateCategories()

        // 2. Items (optional)
        if options.includeItems {
            try await migrateItems()
        }

        // 3. Customers
        try await migrateCustomers()

        // 4. Vendors
        try await migrateVendors()

        // 5. Invoices
        try await migrateInvoices()

        // 6. Expenses
        try await migrateExpenses()

        // 7. Payments
        try await migratePayments()

        print("\n=== Migration Complete ===\n")
    }

    // MARK: - Migrate Categories

    func migrateCategories() async throws {
        print("Migrating categories...")
        var stats = MigrationStats()

        let categories = try await freshBooksAPI.fetchCategories()

        if options.useConfigMapping {
            // Use hierarchical config mapping
            try await migrateHierarchicalCategories(categories: categories, stats: &stats)
        } else {
            // Direct 1:1 mapping
            for category in categories {
                guard category.isActive else {
                    if options.verbose {
                        print("  [SKIP] Category: \(category.displayName) (archived)")
                    }
                    stats.addSkipped()
                    continue
                }

                // Check if exists
                if let existingId = accountNameCache[category.displayName.lowercased()] {
                    if options.verbose {
                        print("  [EXISTS] Category: \(category.displayName) (using existing ID: \(existingId))")
                    }
                    accountIdMapping[category.categoryIdentifier] = existingId
                    stats.addSkipped()
                    continue
                }

                if options.dryRun {
                    print("[DRY RUN] Would create category: \(category.displayName)")
                    stats.addSuccess()
                    continue
                }

                do {
                    let zbAccount = CategoryMapper.map(category)
                    let created = try await zohoAPI.createAccount(zbAccount)
                    if let id = created.accountId {
                        accountIdMapping[category.categoryIdentifier] = id
                        accountNameCache[category.displayName.lowercased()] = id
                        if options.verbose {
                            print("  [CREATE] Category: \(category.displayName)")
                        }
                        stats.addSuccess()
                    }
                } catch {
                    stats.addFailure(entity: category.displayName, error: error.localizedDescription)
                }
            }
        }

        stats.printSummary(entityType: "Categories")
    }

    private func migrateHierarchicalCategories(categories: [FBCategory], stats: inout MigrationStats) async throws {
        guard let categoryConfig = await configManager.getCategoryMapping() else {
            // Fall back to direct mapping
            return
        }

        // Create parent accounts first
        if let hierarchyItems = categoryConfig.categories {
            for item in hierarchyItems {
                // Create parent if not exists
                if accountNameCache[item.name.lowercased()] == nil {
                    if options.dryRun {
                        print("[DRY RUN] Would create parent category: \(item.name)")
                    } else {
                        let account = CategoryMapper.mapFromConfig(name: item.name)
                        if let created = try? await zohoAPI.createAccount(account),
                           let id = created.accountId {
                            accountNameCache[item.name.lowercased()] = id
                            if options.verbose {
                                print("  [CREATE] Parent category: \(item.name)")
                            }
                        }
                    }
                }

                // Create children
                if let children = item.children {
                    let parentId = accountNameCache[item.name.lowercased()]
                    for child in children {
                        if accountNameCache[child.lowercased()] == nil {
                            if options.dryRun {
                                print("[DRY RUN] Would create child category: \(child) under \(item.name)")
                            } else {
                                let childAccount = CategoryMapper.mapFromConfig(
                                    name: child,
                                    parentAccountId: parentId
                                )
                                if let created = try? await zohoAPI.createAccount(childAccount),
                                   let id = created.accountId {
                                    accountNameCache[child.lowercased()] = id
                                    if options.verbose {
                                        print("  [CREATE] Child category: \(child)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Map FreshBooks categories using mapping config
        for category in categories {
            guard category.isActive else {
                stats.addSkipped()
                continue
            }

            let mappedName = await configManager.getMappedCategoryName(for: category.displayName) ?? category.displayName

            if let zohoId = accountNameCache[mappedName.lowercased()] {
                accountIdMapping[category.categoryIdentifier] = zohoId
                stats.addSuccess()
            } else {
                stats.addFailure(entity: category.displayName, error: "No mapping found")
            }
        }
    }

    // MARK: - Migrate Items

    func migrateItems() async throws {
        print("Migrating items...")
        var stats = MigrationStats()

        let items = try await freshBooksAPI.fetchItems()

        for item in items {
            guard item.isActive else {
                if options.verbose {
                    print("  [SKIP] Item: \(item.displayName) (archived)")
                }
                stats.addSkipped()
                continue
            }

            // Check if exists
            if let existing = try? await zohoAPI.searchItemByName(item.displayName),
               let existingId = existing.itemId {
                if options.verbose {
                    print("  [EXISTS] Item: \(item.displayName) (using existing ID: \(existingId))")
                }
                itemIdMapping[item.id] = existingId
                stats.addSkipped()
                continue
            }

            if options.dryRun {
                print("[DRY RUN] Would create item: \(item.displayName)")
                stats.addSuccess()
                continue
            }

            do {
                let zbItem = ItemMapper.map(item)
                let created = try await zohoAPI.createItem(zbItem)
                if let id = created.itemId {
                    itemIdMapping[item.id] = id
                    if options.verbose {
                        print("  [CREATE] Item: \(item.displayName)")
                    }
                    stats.addSuccess()
                }
            } catch {
                stats.addFailure(entity: item.displayName, error: error.localizedDescription)
            }
        }

        stats.printSummary(entityType: "Items")
    }

    // MARK: - Migrate Customers

    func migrateCustomers() async throws {
        print("Migrating customers...")
        var stats = MigrationStats()

        let clients = try await freshBooksAPI.fetchClients()

        for client in clients {
            guard client.isActive else {
                if options.verbose {
                    print("  [SKIP] Customer: \(client.displayName) (archived)")
                }
                stats.addSkipped()
                continue
            }

            // Check if exists
            if let existing = try? await zohoAPI.searchContactByName(client.displayName, contactType: "customer"),
               let existingId = existing.contactId {
                if options.verbose {
                    print("  [EXISTS] Customer: \(client.displayName) (using existing ID: \(existingId))")
                }
                customerIdMapping[client.id] = existingId
                stats.addSkipped()
                continue
            }

            if options.dryRun {
                print("[DRY RUN] Would create customer: \(client.displayName)")
                stats.addSuccess()
                continue
            }

            do {
                let zbContact = CustomerMapper.map(client)
                let created = try await zohoAPI.createContact(zbContact)
                if let id = created.contactId {
                    customerIdMapping[client.id] = id
                    if options.verbose {
                        print("  [CREATE] Customer: \(client.displayName)")
                    }
                    stats.addSuccess()
                }
            } catch {
                stats.addFailure(entity: client.displayName, error: error.localizedDescription)
            }
        }

        // Handle manual customer mapping from config
        if let manualMapping = await configManager.getManualCustomerMapping() {
            for (fbId, customerName) in manualMapping {
                if let fbIdInt = Int(fbId),
                   customerIdMapping[fbIdInt] == nil {
                    if let existing = try? await zohoAPI.searchContactByName(customerName, contactType: "customer"),
                       let existingId = existing.contactId {
                        customerIdMapping[fbIdInt] = existingId
                        if options.verbose {
                            print("  [MANUAL] Mapped archived client \(fbId) to customer: \(customerName)")
                        }
                    }
                }
            }
        }

        stats.printSummary(entityType: "Customers")
    }

    // MARK: - Migrate Vendors

    func migrateVendors() async throws {
        print("Migrating vendors...")
        var stats = MigrationStats()

        let vendors = try await freshBooksAPI.fetchVendors()

        for vendor in vendors {
            guard vendor.isActive else {
                if options.verbose {
                    print("  [SKIP] Vendor: \(vendor.displayName) (archived)")
                }
                stats.addSkipped()
                continue
            }

            // Check if exists in cache
            if let existingId = vendorNameCache[vendor.displayName.lowercased()] {
                if options.verbose {
                    print("  [EXISTS] Vendor: \(vendor.displayName) (using existing ID: \(existingId))")
                }
                vendorIdMapping[vendor.vendorId] = existingId
                stats.addSkipped()
                continue
            }

            if options.dryRun {
                print("[DRY RUN] Would create vendor: \(vendor.displayName)")
                stats.addSuccess()
                continue
            }

            do {
                let zbContact = VendorMapper.map(vendor)
                let created = try await zohoAPI.createContact(zbContact)
                if let id = created.contactId {
                    vendorIdMapping[vendor.vendorId] = id
                    vendorNameCache[vendor.displayName.lowercased()] = id
                    if options.verbose {
                        print("  [CREATE] Vendor: \(vendor.displayName)")
                    }
                    stats.addSuccess()
                }
            } catch {
                stats.addFailure(entity: vendor.displayName, error: error.localizedDescription)
            }
        }

        stats.printSummary(entityType: "Vendors")
    }

    // MARK: - Migrate Invoices

    func migrateInvoices() async throws {
        print("Migrating invoices...")
        var stats = MigrationStats()

        let invoices = try await freshBooksAPI.fetchInvoices()

        for invoice in invoices {
            guard invoice.isActive else {
                if options.verbose {
                    print("  [SKIP] Invoice: \(invoice.invoiceNumber ?? "unknown") (archived)")
                }
                stats.addSkipped()
                continue
            }

            // Must have customer mapping
            guard let customerId = invoice.customerId,
                  let zohoCustomerId = customerIdMapping[customerId] else {
                if options.verbose {
                    print("  [SKIP] Invoice: \(invoice.invoiceNumber ?? "unknown") (no customer mapping)")
                }
                stats.addSkipped()
                continue
            }

            // Check if exists
            if let invoiceNum = invoice.invoiceNumber,
               let existing = try? await zohoAPI.searchInvoiceByNumber(invoiceNum),
               let existingId = existing.invoiceId {
                if options.verbose {
                    print("  [EXISTS] Invoice: \(invoiceNum) (using existing ID: \(existingId))")
                }
                invoiceIdMapping[invoice.id] = existingId
                stats.addSkipped()
                continue
            }

            if options.dryRun {
                print("[DRY RUN] Would create invoice: \(invoice.invoiceNumber ?? "unknown")")
                stats.addSuccess()
                continue
            }

            do {
                let zbInvoice = InvoiceMapper.map(
                    invoice,
                    customerId: zohoCustomerId,
                    taxLookup: { [taxNameCache] taxName in
                        guard let name = taxName else { return nil }
                        return taxNameCache[name.lowercased()]
                    },
                    taxExemptionId: serviceTaxExemptionId
                )

                let created = try await zohoAPI.createInvoice(zbInvoice)
                if let id = created.invoiceId {
                    invoiceIdMapping[invoice.id] = id

                    // Mark as sent if not draft
                    if invoice.shouldMarkAsSent {
                        try? await zohoAPI.markInvoiceAsSent(id)
                    }

                    if options.verbose {
                        print("  [CREATE] Invoice: \(invoice.invoiceNumber ?? "unknown")")
                    }
                    stats.addSuccess()
                }
            } catch {
                stats.addFailure(entity: invoice.invoiceNumber ?? "Invoice \(invoice.id)", error: error.localizedDescription)
            }
        }

        stats.printSummary(entityType: "Invoices")
    }

    // MARK: - Migrate Expenses

    func migrateExpenses() async throws {
        print("Migrating expenses...")
        var stats = MigrationStats()

        let expenses = try await freshBooksAPI.fetchExpenses()

        for expense in expenses {
            guard expense.isActive else {
                if options.verbose {
                    print("  [SKIP] Expense ID \(expense.id) (archived)")
                }
                stats.addSkipped()
                continue
            }

            // Must have account mapping
            guard let categoryId = expense.categoryId,
                  let accountId = accountIdMapping[categoryId] else {
                if options.verbose {
                    print("  [SKIP] Expense ID \(expense.id) (no account mapping for category \(expense.categoryId ?? 0))")
                }
                stats.addSkipped()
                continue
            }

            // Handle vendor (on-the-fly creation if needed)
            var vendorId: String?
            if let vendorName = expense.vendor, !vendorName.isEmpty {
                if let existingVendorId = vendorNameCache[vendorName.lowercased()] {
                    vendorId = existingVendorId
                } else if !options.dryRun {
                    // Create vendor on-the-fly
                    do {
                        let newVendor = VendorMapper.mapFromName(vendorName)
                        let created = try await zohoAPI.createContact(newVendor)
                        if let id = created.contactId {
                            vendorId = id
                            vendorNameCache[vendorName.lowercased()] = id
                            if options.verbose {
                                print("  [CREATE] On-the-fly vendor: \(vendorName)")
                            }
                        }
                    } catch {
                        // Non-critical, continue without vendor
                        if options.verbose {
                            print("  [WARN] Failed to create vendor \(vendorName): \(error.localizedDescription)")
                        }
                    }
                }
            }

            // Map customer if billable
            var customerId: String?
            if let clientId = expense.clientId {
                customerId = customerIdMapping[clientId]
            }

            // Map paid through account
            var paidThroughAccountId: String?
            if let accountName = expense.accountName {
                let mappedName = await configManager.getPaidThroughAccountName(for: accountName) ?? accountName
                paidThroughAccountId = accountNameCache[mappedName.lowercased()]
            }

            // Map tax
            var taxId: String?
            if let taxName = expense.taxName1 {
                taxId = taxNameCache[taxName.lowercased()]
            }

            if options.dryRun {
                print("[DRY RUN] Would create expense: \(expense.expenseDate) - $\(expense.amountValue)")
                stats.addSuccess()
                continue
            }

            do {
                let zbExpense = ExpenseMapper.map(
                    expense,
                    accountId: accountId,
                    vendorId: vendorId,
                    customerId: customerId,
                    paidThroughAccountId: paidThroughAccountId,
                    taxId: taxId
                )

                let created = try await zohoAPI.createExpense(zbExpense)

                // Handle attachment
                if options.includeAttachments,
                   let expenseId = created.expenseId,
                   let attachment = expense.attachment,
                   let jwt = attachment.jwt {
                    do {
                        let fileData = try await freshBooksAPI.downloadAttachment(
                            jwt: jwt,
                            filename: attachment.filename ?? "receipt"
                        )
                        let mimeType = attachment.mediaType ?? "application/octet-stream"
                        let filename = attachment.filename ?? "receipt.jpg"
                        try await zohoAPI.uploadReceipt(
                            expenseId: expenseId,
                            fileData: fileData,
                            filename: filename,
                            mimeType: mimeType
                        )
                        if options.verbose {
                            print("  [UPLOAD] Receipt for expense ID \(expenseId)")
                        }
                    } catch {
                        if options.verbose {
                            print("  [WARN] Failed to upload receipt: \(error.localizedDescription)")
                        }
                    }
                }

                if options.verbose {
                    print("  [CREATE] Expense: \(expense.expenseDate) - $\(expense.amountValue)")
                }
                stats.addSuccess()
            } catch {
                stats.addFailure(entity: "Expense \(expense.id)", error: error.localizedDescription)
            }
        }

        stats.printSummary(entityType: "Expenses")
    }

    // MARK: - Migrate Payments

    func migratePayments() async throws {
        print("Migrating payments...")
        var stats = MigrationStats()

        let payments = try await freshBooksAPI.fetchPayments()

        for payment in payments {
            guard payment.isActive else {
                if options.verbose {
                    print("  [SKIP] Payment ID \(payment.id) (archived)")
                }
                stats.addSkipped()
                continue
            }

            // Must have customer mapping
            guard let clientId = payment.clientId,
                  let customerId = customerIdMapping[clientId] else {
                if options.verbose {
                    print("  [SKIP] Payment ID \(payment.id) (no customer mapping)")
                }
                stats.addSkipped()
                continue
            }

            // Map invoice if linked
            var invoiceId: String?
            if let fbInvoiceId = payment.invoiceId {
                invoiceId = invoiceIdMapping[fbInvoiceId]
            }

            // Get deposit account
            let gateway = payment.gateway ?? payment.type ?? "default"
            let depositAccountName = await configManager.getDepositAccount(for: gateway)
            let depositAccountId = accountNameCache[depositAccountName.lowercased()]

            if options.dryRun {
                print("[DRY RUN] Would create payment: \(payment.date ?? "unknown") - $\(payment.amountValue)")
                stats.addSuccess()
                continue
            }

            do {
                let zbPayment = PaymentMapper.map(
                    payment,
                    customerId: customerId,
                    invoiceId: invoiceId,
                    depositAccountId: depositAccountId
                )

                _ = try await zohoAPI.createPayment(zbPayment)

                if options.verbose {
                    print("  [CREATE] Payment: \(payment.date ?? "unknown") - $\(payment.amountValue)")
                }
                stats.addSuccess()
            } catch {
                stats.addFailure(entity: "Payment \(payment.id)", error: error.localizedDescription)
            }
        }

        stats.printSummary(entityType: "Payments")
    }
}
