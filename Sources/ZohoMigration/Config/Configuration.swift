import Foundation

// MARK: - FreshBooks Configuration

struct FreshBooksConfig: Codable {
    var clientId: String
    var clientSecret: String
    var accessToken: String
    var refreshToken: String
    var accountId: String

    enum CodingKeys: String, CodingKey {
        case clientId
        case clientSecret
        case accessToken
        case refreshToken
        case accountId
    }
}

// MARK: - Zoho Configuration

struct ZohoConfig: Codable {
    var clientId: String
    var clientSecret: String
    var accessToken: String
    var refreshToken: String
    var organizationId: String
    var region: String // "com", "eu", "in", "com.au"

    enum CodingKeys: String, CodingKey {
        case clientId
        case clientSecret
        case accessToken
        case refreshToken
        case organizationId
        case region
    }

    var baseURL: String {
        switch region.lowercased() {
        case "eu":
            return "https://www.zohoapis.eu/books/v3"
        case "in":
            return "https://www.zohoapis.in/books/v3"
        case "com.au", "au":
            return "https://www.zohoapis.com.au/books/v3"
        default:
            return "https://www.zohoapis.com/books/v3"
        }
    }

    var accountsURL: String {
        switch region.lowercased() {
        case "eu":
            return "https://accounts.zoho.eu"
        case "in":
            return "https://accounts.zoho.in"
        case "com.au", "au":
            return "https://accounts.zoho.com.au"
        default:
            return "https://accounts.zoho.com"
        }
    }
}

// MARK: - Category Hierarchy Configuration

struct CategoryHierarchyItem: Codable {
    let name: String
    let children: [String]?
}

struct CategoryMappingConfig: Codable {
    let categories: [CategoryHierarchyItem]?
    let mapping: [String: String]?
}

// MARK: - Main Configuration

struct Configuration: Codable {
    var freshbooks: FreshBooksConfig
    var zoho: ZohoConfig
    var categoryMapping: CategoryMappingConfig?
    var paidThroughMapping: [String: String]?
    var depositAccountMapping: [String: String]?
    var manualCustomerMapping: [String: String]?

    enum CodingKeys: String, CodingKey {
        case freshbooks
        case zoho
        case categoryMapping
        case paidThroughMapping
        case depositAccountMapping
        case manualCustomerMapping
    }
}

// MARK: - Configuration Manager

actor ConfigurationManager {
    private var configuration: Configuration
    private let configPath: String

    init(configPath: String) async throws {
        self.configPath = configPath
        let url = URL(fileURLWithPath: configPath)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        self.configuration = try decoder.decode(Configuration.self, from: data)
    }

    func getConfiguration() -> Configuration {
        return configuration
    }

    func getFreshBooksConfig() -> FreshBooksConfig {
        return configuration.freshbooks
    }

    func getZohoConfig() -> ZohoConfig {
        return configuration.zoho
    }

    func updateFreshBooksToken(_ token: String) async throws {
        configuration.freshbooks.accessToken = token
        try await saveConfiguration()
    }

    func updateZohoToken(_ token: String) async throws {
        configuration.zoho.accessToken = token
        try await saveConfiguration()
    }

    func updateFreshBooksTokens(accessToken: String, refreshToken: String) async throws {
        configuration.freshbooks.accessToken = accessToken
        configuration.freshbooks.refreshToken = refreshToken
        try await saveConfiguration()
    }

    func updateZohoTokens(accessToken: String, refreshToken: String) async throws {
        configuration.zoho.accessToken = accessToken
        configuration.zoho.refreshToken = refreshToken
        try await saveConfiguration()
    }

    private func saveConfiguration() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        let url = URL(fileURLWithPath: configPath)
        try data.write(to: url)
    }

    func getPaidThroughAccountName(for accountName: String) -> String? {
        return configuration.paidThroughMapping?[accountName]
    }

    func getDepositAccount(for gateway: String) -> String {
        if let mapping = configuration.depositAccountMapping {
            if let account = mapping[gateway.lowercased()] {
                return account
            }
            return mapping["default"] ?? "Checking"
        }
        return "Checking"
    }

    func getCategoryMapping() -> CategoryMappingConfig? {
        return configuration.categoryMapping
    }

    func getManualCustomerMapping() -> [String: String]? {
        return configuration.manualCustomerMapping
    }

    func getMappedCategoryName(for fbName: String) -> String? {
        return configuration.categoryMapping?.mapping?[fbName]
    }
}
