import Foundation

// MARK: - Zoho API Errors

enum ZohoAPIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case networkError(Error)
    case apiError(Int, String)
    case decodingError(Error)
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .unauthorized:
            return "Unauthorized - token may be expired"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        }
    }
}

// MARK: - Generic Zoho Response

struct ZohoGenericResponse: Codable {
    let code: Int
    let message: String
}

// MARK: - Zoho API Actor

actor ZohoAPI {
    private let configManager: ConfigurationManager
    private let oauthHelper: OAuthHelper
    private var accessToken: String

    // Rate limiting
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 100

    init(configManager: ConfigurationManager, oauthHelper: OAuthHelper) async {
        self.configManager = configManager
        self.oauthHelper = oauthHelper
        self.accessToken = await configManager.getZohoConfig().accessToken
    }

    private func getBaseURL() async -> String {
        return await configManager.getZohoConfig().baseURL
    }

    private func getOrganizationId() async -> String {
        return await configManager.getZohoConfig().organizationId
    }

    // MARK: - Rate Limiting

    private func checkRateLimit() async {
        // Remove timestamps older than 60 seconds
        let cutoff = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > cutoff }

        if requestTimestamps.count >= maxRequestsPerMinute {
            let oldestInWindow = requestTimestamps.first!
            let waitTime = oldestInWindow.addingTimeInterval(60).timeIntervalSinceNow
            if waitTime > 0 {
                print("Rate limit approaching (\(requestTimestamps.count)/\(maxRequestsPerMinute) requests), waiting \(Int(waitTime))s...")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        requestTimestamps.append(Date())
    }

    // MARK: - HTTP Request Helpers

    private func makeGetRequest<T: Decodable>(
        endpoint: String,
        queryParams: [String: String] = [:],
        responseType: T.Type,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        await checkRateLimit()

        let baseURL = await getBaseURL()
        let orgId = await getOrganizationId()

        var allParams = queryParams
        allParams["organization_id"] = orgId

        let queryString = allParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let urlString = "\(baseURL)/\(endpoint)?\(queryString)"

        guard let url = URL(string: urlString) else {
            throw ZohoAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Zoho-oauthtoken \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ZohoAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 && retryOnUnauthorized {
                accessToken = try await oauthHelper.refreshZohoToken()
                return try await makeGetRequest(
                    endpoint: endpoint,
                    queryParams: queryParams,
                    responseType: responseType,
                    retryOnUnauthorized: false
                )
            }

            if httpResponse.statusCode == 429 {
                throw ZohoAPIError.rateLimitExceeded
            }

            return try JSONDecoder().decode(responseType, from: data)
        } catch let error as ZohoAPIError {
            throw error
        } catch let error as DecodingError {
            throw ZohoAPIError.decodingError(error)
        } catch {
            throw ZohoAPIError.networkError(error)
        }
    }

    private func makePostRequest<T: Decodable>(
        endpoint: String,
        body: Data,
        responseType: T.Type,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        await checkRateLimit()

        let baseURL = await getBaseURL()
        let orgId = await getOrganizationId()

        let urlString = "\(baseURL)/\(endpoint)?organization_id=\(orgId)"

        guard let url = URL(string: urlString) else {
            throw ZohoAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Zoho-oauthtoken \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ZohoAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 && retryOnUnauthorized {
                accessToken = try await oauthHelper.refreshZohoToken()
                return try await makePostRequest(
                    endpoint: endpoint,
                    body: body,
                    responseType: responseType,
                    retryOnUnauthorized: false
                )
            }

            if httpResponse.statusCode == 429 {
                throw ZohoAPIError.rateLimitExceeded
            }

            // Check for Zoho error response
            if let genericResponse = try? JSONDecoder().decode(ZohoGenericResponse.self, from: data),
               genericResponse.code != 0 {
                throw ZohoAPIError.apiError(genericResponse.code, genericResponse.message)
            }

            return try JSONDecoder().decode(responseType, from: data)
        } catch let error as ZohoAPIError {
            throw error
        } catch let error as DecodingError {
            throw ZohoAPIError.decodingError(error)
        } catch {
            throw ZohoAPIError.networkError(error)
        }
    }

    // MARK: - Contacts (Customers and Vendors)

    func fetchContacts(contactType: String? = nil) async throws -> [ZBContact] {
        var params: [String: String] = [:]
        if let type = contactType {
            params["contact_type"] = type
        }

        let response = try await makeGetRequest(
            endpoint: "contacts",
            queryParams: params,
            responseType: ZBContactsListResponse.self
        )

        return response.contacts ?? []
    }

    func createContact(_ contact: ZBContact) async throws -> ZBContact {
        let encoder = JSONEncoder()
        let data = try encoder.encode(contact)

        let response = try await makePostRequest(
            endpoint: "contacts",
            body: data,
            responseType: ZBContactResponse.self
        )

        guard let created = response.contact else {
            throw ZohoAPIError.apiError(response.code, response.message)
        }

        return created
    }

    func searchContactByName(_ name: String, contactType: String? = nil) async throws -> ZBContact? {
        let contacts = try await fetchContacts(contactType: contactType)
        return contacts.first { $0.contactName.lowercased() == name.lowercased() }
    }

    // MARK: - Invoices

    func fetchInvoices() async throws -> [ZBInvoice] {
        let response = try await makeGetRequest(
            endpoint: "invoices",
            responseType: ZBInvoicesListResponse.self
        )
        return response.invoices ?? []
    }

    func createInvoice(_ invoice: ZBInvoice) async throws -> ZBInvoice {
        let encoder = JSONEncoder()
        let data = try encoder.encode(invoice)

        let response = try await makePostRequest(
            endpoint: "invoices",
            body: data,
            responseType: ZBInvoiceResponse.self
        )

        guard let created = response.invoice else {
            throw ZohoAPIError.apiError(response.code, response.message)
        }

        return created
    }

    func markInvoiceAsSent(_ invoiceId: String) async throws {
        await checkRateLimit()

        let baseURL = await getBaseURL()
        let orgId = await getOrganizationId()

        let urlString = "\(baseURL)/invoices/\(invoiceId)/status/sent?organization_id=\(orgId)"

        guard let url = URL(string: urlString) else {
            throw ZohoAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Zoho-oauthtoken \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Non-critical, don't throw
            return
        }
    }

    func searchInvoiceByNumber(_ invoiceNumber: String) async throws -> ZBInvoice? {
        let invoices = try await fetchInvoices()
        return invoices.first { $0.invoiceNumber == invoiceNumber }
    }

    // MARK: - Expenses

    func fetchExpenses() async throws -> [ZBExpense] {
        let response = try await makeGetRequest(
            endpoint: "expenses",
            responseType: ZBExpensesListResponse.self
        )
        return response.expenses ?? []
    }

    func createExpense(_ expense: ZBExpense) async throws -> ZBExpense {
        let encoder = JSONEncoder()
        let data = try encoder.encode(expense)

        let response = try await makePostRequest(
            endpoint: "expenses",
            body: data,
            responseType: ZBExpenseResponse.self
        )

        guard let created = response.expense else {
            throw ZohoAPIError.apiError(response.code, response.message)
        }

        return created
    }

    func uploadReceipt(expenseId: String, fileData: Data, filename: String, mimeType: String) async throws {
        await checkRateLimit()

        let baseURL = await getBaseURL()
        let orgId = await getOrganizationId()

        let urlString = "\(baseURL)/expenses/\(expenseId)/receipt?organization_id=\(orgId)"

        guard let url = URL(string: urlString) else {
            throw ZohoAPIError.invalidResponse
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Zoho-oauthtoken \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"receipt\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Non-critical, don't throw
            return
        }
    }

    // MARK: - Payments

    func fetchPayments() async throws -> [ZBPayment] {
        let response = try await makeGetRequest(
            endpoint: "customerpayments",
            responseType: ZBPaymentsListResponse.self
        )
        return response.customerpayments ?? []
    }

    func createPayment(_ payment: ZBPayment) async throws -> ZBPayment {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payment)

        let response = try await makePostRequest(
            endpoint: "customerpayments",
            body: data,
            responseType: ZBPaymentResponse.self
        )

        guard let created = response.payment else {
            throw ZohoAPIError.apiError(response.code, response.message)
        }

        return created
    }

    // MARK: - Chart of Accounts

    func fetchAccounts() async throws -> [ZBAccount] {
        let response = try await makeGetRequest(
            endpoint: "chartofaccounts",
            responseType: ZBAccountsListResponse.self
        )
        return response.chartofaccounts ?? []
    }

    func createAccount(_ account: ZBAccount) async throws -> ZBAccount {
        let encoder = JSONEncoder()
        let data = try encoder.encode(account)

        let response = try await makePostRequest(
            endpoint: "chartofaccounts",
            body: data,
            responseType: ZBAccountResponse.self
        )

        guard let created = response.chartofaccount else {
            throw ZohoAPIError.apiError(response.code, response.message)
        }

        return created
    }

    func searchAccountByName(_ name: String) async throws -> ZBAccount? {
        let accounts = try await fetchAccounts()
        return accounts.first { $0.accountName.lowercased() == name.lowercased() }
    }

    // MARK: - Items

    func fetchItems() async throws -> [ZBItem] {
        let response = try await makeGetRequest(
            endpoint: "items",
            responseType: ZBItemsListResponse.self
        )
        return response.items ?? []
    }

    func createItem(_ item: ZBItem) async throws -> ZBItem {
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let response = try await makePostRequest(
            endpoint: "items",
            body: data,
            responseType: ZBItemResponse.self
        )

        guard let created = response.item else {
            throw ZohoAPIError.apiError(response.code, response.message)
        }

        return created
    }

    func searchItemByName(_ name: String) async throws -> ZBItem? {
        let items = try await fetchItems()
        return items.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Taxes

    func fetchTaxes() async throws -> [ZBTax] {
        let response = try await makeGetRequest(
            endpoint: "settings/taxes",
            responseType: ZBTaxesResponse.self
        )
        return response.taxes ?? []
    }

    func fetchTaxExemptions() async throws -> [ZBTaxExemption] {
        let response = try await makeGetRequest(
            endpoint: "settings/taxexemptions",
            responseType: ZBTaxExemptionsResponse.self
        )
        return response.taxExemptions ?? []
    }

    func searchTaxByName(_ name: String) async throws -> ZBTax? {
        let taxes = try await fetchTaxes()
        return taxes.first { ($0.taxName ?? "").lowercased() == name.lowercased() }
    }

    func getServiceTaxExemption() async throws -> ZBTaxExemption? {
        let exemptions = try await fetchTaxExemptions()
        return exemptions.first {
            ($0.taxExemptionCode ?? "").lowercased().contains("service") ||
            ($0.description ?? "").lowercased().contains("service")
        }
    }
}
