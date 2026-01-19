import ArgumentParser
import Foundation

// MARK: - Main CLI Command

@main
struct ZohoMigration: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "zoho-migration",
        abstract: "FreshBooks to Zoho Books Migration CLI Tool",
        version: "1.0.0",
        subcommands: [Migrate.self, Auth.self]
    )
}

// MARK: - Common Options

struct CommonOptions: ParsableArguments {
    @Flag(name: .long, help: "Fetch data but don't create anything in Zoho")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Print each entity being processed")
    var verbose: Bool = false

    @Option(name: .long, help: "Path to config file")
    var config: String = "./config.json"

    @Flag(name: .long, help: "Use hierarchical category mapping from config")
    var useConfigMapping: Bool = false

    @Flag(name: .long, help: "Include items migration (skipped by default)")
    var includeItems: Bool = false

    @Flag(name: .long, help: "Download/upload expense receipts")
    var includeAttachments: Bool = false

    func toMigrationOptions() -> MigrationOptions {
        return MigrationOptions(
            dryRun: dryRun,
            verbose: verbose,
            useConfigMapping: useConfigMapping,
            includeItems: includeItems,
            includeAttachments: includeAttachments
        )
    }
}

// MARK: - Migrate Command Group

struct Migrate: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Run migrations",
        subcommands: [
            MigrateAll.self,
            MigrateCustomers.self,
            MigrateVendors.self,
            MigrateInvoices.self,
            MigrateExpenses.self,
            MigrateCategories.self,
            MigrateItems.self,
            MigratePayments.self
        ],
        defaultSubcommand: MigrateAll.self
    )
}

// MARK: - Migration Helper

func createMigrationService(configPath: String, options: MigrationOptions) async throws -> MigrationService {
    let configManager = try await ConfigurationManager(configPath: configPath)
    let oauthHelper = OAuthHelper(configManager: configManager)
    let freshBooksAPI = await FreshBooksAPI(configManager: configManager, oauthHelper: oauthHelper)
    let zohoAPI = await ZohoAPI(configManager: configManager, oauthHelper: oauthHelper)
    let service = MigrationService(freshBooksAPI: freshBooksAPI, zohoAPI: zohoAPI, configManager: configManager)
    await service.setOptions(options)
    return service
}

// MARK: - Migrate All

struct MigrateAll: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "all",
        abstract: "Migrate all entities in dependency order"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Starting full migration...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateAll()
    }
}

// MARK: - Migrate Customers

struct MigrateCustomers: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "customers",
        abstract: "Migrate customers only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating customers...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateCustomers()
    }
}

// MARK: - Migrate Vendors

struct MigrateVendors: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vendors",
        abstract: "Migrate vendors only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating vendors...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateVendors()
    }
}

// MARK: - Migrate Invoices

struct MigrateInvoices: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "invoices",
        abstract: "Migrate invoices only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating invoices...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateInvoices()
    }
}

// MARK: - Migrate Expenses

struct MigrateExpenses: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "expenses",
        abstract: "Migrate expenses only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating expenses...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateExpenses()
    }
}

// MARK: - Migrate Categories

struct MigrateCategories: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "categories",
        abstract: "Migrate expense categories only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating categories...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateCategories()
    }
}

// MARK: - Migrate Items

struct MigrateItems: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "items",
        abstract: "Migrate items/products only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating items...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migrateItems()
    }
}

// MARK: - Migrate Payments

struct MigratePayments: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "payments",
        abstract: "Migrate payments only"
    )

    @OptionGroup var options: CommonOptions

    func run() async throws {
        print("Migrating payments...")
        let service = try await createMigrationService(configPath: options.config, options: options.toMigrationOptions())
        try await service.migratePayments()
    }
}

// MARK: - Auth Command Group

struct Auth: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "OAuth authentication helpers",
        subcommands: [AuthFreshBooks.self, AuthZoho.self]
    )
}

// MARK: - Auth FreshBooks

struct AuthFreshBooks: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "freshbooks",
        abstract: "Authenticate with FreshBooks"
    )

    @Option(name: .long, help: "OAuth redirect URI")
    var redirectUri: String = "http://localhost:8080/callback"

    @Option(name: .long, help: "Path to config file")
    var config: String = "./config.json"

    func run() async throws {
        // Load config to get client ID
        let configURL = URL(fileURLWithPath: config)
        let configData = try Data(contentsOf: configURL)
        let configuration = try JSONDecoder().decode(Configuration.self, from: configData)

        let clientId = configuration.freshbooks.clientId
        let clientSecret = configuration.freshbooks.clientSecret

        let authURL = OAuthHelper.getFreshBooksAuthURL(clientId: clientId, redirectUri: redirectUri)

        print("Open this URL in your browser to authorize:")
        print(authURL)
        print("")
        print("After authorizing, you'll be redirected to \(redirectUri)?code=XXXXX")
        print("Paste the authorization code here:")

        guard let code = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            print("Error: No code provided")
            return
        }

        print("Exchanging code for tokens...")

        let configManager = try await ConfigurationManager(configPath: config)
        let oauthHelper = OAuthHelper(configManager: configManager)

        let tokens = try await oauthHelper.exchangeFreshBooksCode(
            code,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri
        )

        try await configManager.updateFreshBooksTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken ?? ""
        )

        print("Success! FreshBooks tokens saved to config.json")
    }
}

// MARK: - Auth Zoho

struct AuthZoho: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "zoho",
        abstract: "Authenticate with Zoho Books"
    )

    @Option(name: .long, help: "OAuth redirect URI")
    var redirectUri: String = "http://localhost:8080/callback"

    @Option(name: .long, help: "Path to config file")
    var config: String = "./config.json"

    func run() async throws {
        // Load config to get client ID
        let configURL = URL(fileURLWithPath: config)
        let configData = try Data(contentsOf: configURL)
        let configuration = try JSONDecoder().decode(Configuration.self, from: configData)

        let clientId = configuration.zoho.clientId
        let clientSecret = configuration.zoho.clientSecret
        let region = configuration.zoho.region

        let authURL = OAuthHelper.getZohoAuthURL(clientId: clientId, redirectUri: redirectUri, region: region)

        print("Open this URL in your browser to authorize:")
        print(authURL)
        print("")
        print("After authorizing, you'll be redirected to \(redirectUri)?code=XXXXX")
        print("Paste the authorization code here:")

        guard let code = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            print("Error: No code provided")
            return
        }

        print("Exchanging code for tokens...")

        let configManager = try await ConfigurationManager(configPath: config)
        let oauthHelper = OAuthHelper(configManager: configManager)

        let tokens = try await oauthHelper.exchangeZohoCode(
            code,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri,
            region: region
        )

        try await configManager.updateZohoTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken ?? ""
        )

        print("Success! Zoho tokens saved to config.json")
    }
}
