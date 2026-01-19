import Foundation

// MARK: - FreshBooks API Errors

enum FreshBooksAPIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case networkError(Error)
    case apiError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .unauthorized:
            return "Unauthorized - token may be expired"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - FreshBooks API Actor

actor FreshBooksAPI {
    private let configManager: ConfigurationManager
    private let oauthHelper: OAuthHelper
    private var accessToken: String

    private let baseURL = "https://api.freshbooks.com"
    private let perPage = 100

    init(configManager: ConfigurationManager, oauthHelper: OAuthHelper) async {
        self.configManager = configManager
        self.oauthHelper = oauthHelper
        self.accessToken = await configManager.getFreshBooksConfig().accessToken
    }

    private func getAccountId() async -> String {
        return await configManager.getFreshBooksConfig().accountId
    }

    // MARK: - HTTP Request Helper

    private func makeRequest<T: Decodable>(
        endpoint: String,
        queryParams: [String: String] = [:],
        responseType: T.Type,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        let accountId = await getAccountId()
        var urlString = "\(baseURL)/accounting/account/\(accountId)/\(endpoint)"

        if !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw FreshBooksAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FreshBooksAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 && retryOnUnauthorized {
                // Refresh token and retry
                accessToken = try await oauthHelper.refreshFreshBooksToken()
                return try await makeRequest(
                    endpoint: endpoint,
                    queryParams: queryParams,
                    responseType: responseType,
                    retryOnUnauthorized: false
                )
            }

            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw FreshBooksAPIError.apiError("Status \(httpResponse.statusCode): \(errorMessage)")
            }

            do {
                let decoded = try JSONDecoder().decode(responseType, from: data)
                return decoded
            } catch {
                throw FreshBooksAPIError.decodingError(error)
            }
        } catch let error as FreshBooksAPIError {
            throw error
        } catch {
            throw FreshBooksAPIError.networkError(error)
        }
    }

    // MARK: - Paginated Fetch Helper

    private func fetchAllPaginated<T, R>(
        endpoint: String,
        responseType: R.Type,
        extractItems: @escaping (R) -> [T],
        extractPagination: @escaping (R) -> (page: Int, pages: Int)
    ) async throws -> [T] where R: Decodable {
        var allItems: [T] = []
        var currentPage = 1

        while true {
            let queryParams = [
                "page": "\(currentPage)",
                "per_page": "\(perPage)"
            ]

            let response = try await makeRequest(
                endpoint: endpoint,
                queryParams: queryParams,
                responseType: responseType
            )

            let items = extractItems(response)
            allItems.append(contentsOf: items)

            let pagination = extractPagination(response)
            if currentPage >= pagination.pages {
                break
            }
            currentPage += 1
        }

        return allItems
    }

    // MARK: - Fetch Clients (Customers)

    func fetchClients() async throws -> [FBClient] {
        return try await fetchAllPaginated(
            endpoint: "users/clients",
            responseType: FBClientsResponse.self,
            extractItems: { $0.response.result.clients },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Fetch Vendors

    func fetchVendors() async throws -> [FBVendor] {
        return try await fetchAllPaginated(
            endpoint: "bill_vendors/bill_vendors",
            responseType: FBVendorsResponse.self,
            extractItems: { $0.response.result.vendors },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Fetch Invoices

    func fetchInvoices() async throws -> [FBInvoice] {
        return try await fetchAllPaginated(
            endpoint: "invoices/invoices",
            responseType: FBInvoicesResponse.self,
            extractItems: { $0.response.result.invoices },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Fetch Expenses

    func fetchExpenses() async throws -> [FBExpense] {
        return try await fetchAllPaginated(
            endpoint: "expenses/expenses",
            responseType: FBExpensesResponse.self,
            extractItems: { $0.response.result.expenses },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Fetch Payments

    func fetchPayments() async throws -> [FBPayment] {
        return try await fetchAllPaginated(
            endpoint: "payments/payments",
            responseType: FBPaymentsResponse.self,
            extractItems: { $0.response.result.payments },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Fetch Categories

    func fetchCategories() async throws -> [FBCategory] {
        return try await fetchAllPaginated(
            endpoint: "expenses/categories",
            responseType: FBCategoriesResponse.self,
            extractItems: { $0.response.result.categories },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Fetch Items

    func fetchItems() async throws -> [FBItem] {
        return try await fetchAllPaginated(
            endpoint: "items/items",
            responseType: FBItemsResponse.self,
            extractItems: { $0.response.result.items },
            extractPagination: { ($0.response.result.page, $0.response.result.pages) }
        )
    }

    // MARK: - Download Attachment

    func downloadAttachment(jwt: String, filename: String) async throws -> Data {
        let urlString = "https://api.freshbooks.com/uploads/images/\(jwt)"

        guard let url = URL(string: urlString) else {
            throw FreshBooksAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FreshBooksAPIError.apiError("Failed to download attachment")
        }

        return data
    }
}
