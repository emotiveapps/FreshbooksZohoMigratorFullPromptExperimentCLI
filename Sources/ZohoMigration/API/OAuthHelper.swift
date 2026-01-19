import Foundation

// MARK: - OAuth Token Response

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - OAuth Errors

enum OAuthError: Error, LocalizedError {
    case tokenRefreshFailed(String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .invalidResponse:
            return "Invalid OAuth response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - OAuth Helper

actor OAuthHelper {
    private let configManager: ConfigurationManager

    init(configManager: ConfigurationManager) {
        self.configManager = configManager
    }

    // MARK: - FreshBooks Token Refresh

    func refreshFreshBooksToken() async throws -> String {
        let config = await configManager.getFreshBooksConfig()

        let url = URL(string: "https://api.freshbooks.com/auth/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "refresh_token": config.refreshToken
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenRefreshFailed(errorMessage)
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)

        // Update tokens in config
        if let newRefreshToken = tokenResponse.refreshToken {
            try await configManager.updateFreshBooksTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: newRefreshToken
            )
        } else {
            try await configManager.updateFreshBooksToken(tokenResponse.accessToken)
        }

        return tokenResponse.accessToken
    }

    // MARK: - Zoho Token Refresh

    func refreshZohoToken() async throws -> String {
        let config = await configManager.getZohoConfig()

        let url = URL(string: "\(config.accountsURL)/oauth/v2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type=refresh_token",
            "client_id=\(config.clientId)",
            "client_secret=\(config.clientSecret)",
            "refresh_token=\(config.refreshToken)"
        ]

        request.httpBody = bodyParams.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenRefreshFailed(errorMessage)
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)

        // Update tokens in config (Zoho may not return new refresh token)
        if let newRefreshToken = tokenResponse.refreshToken {
            try await configManager.updateZohoTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: newRefreshToken
            )
        } else {
            try await configManager.updateZohoToken(tokenResponse.accessToken)
        }

        return tokenResponse.accessToken
    }

    // MARK: - OAuth Authorization URLs

    static func getFreshBooksAuthURL(clientId: String, redirectUri: String) -> String {
        let baseURL = "https://my.freshbooks.com/service/auth/oauth/authorize"
        let params = [
            "client_id=\(clientId)",
            "response_type=code",
            "redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri)"
        ]
        return "\(baseURL)?\(params.joined(separator: "&"))"
    }

    static func getZohoAuthURL(clientId: String, redirectUri: String, region: String = "com") -> String {
        let accountsBase: String
        switch region.lowercased() {
        case "eu":
            accountsBase = "https://accounts.zoho.eu"
        case "in":
            accountsBase = "https://accounts.zoho.in"
        case "com.au", "au":
            accountsBase = "https://accounts.zoho.com.au"
        default:
            accountsBase = "https://accounts.zoho.com"
        }

        let scope = "ZohoBooks.fullaccess.all"
        let params = [
            "client_id=\(clientId)",
            "response_type=code",
            "scope=\(scope)",
            "redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri)",
            "access_type=offline",
            "prompt=consent"
        ]
        return "\(accountsBase)/oauth/v2/auth?\(params.joined(separator: "&"))"
    }

    // MARK: - Exchange Authorization Code

    func exchangeFreshBooksCode(_ code: String, clientId: String, clientSecret: String, redirectUri: String) async throws -> OAuthTokenResponse {
        let url = URL(string: "https://api.freshbooks.com/auth/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectUri
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenRefreshFailed(errorMessage)
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    func exchangeZohoCode(_ code: String, clientId: String, clientSecret: String, redirectUri: String, region: String = "com") async throws -> OAuthTokenResponse {
        let accountsBase: String
        switch region.lowercased() {
        case "eu":
            accountsBase = "https://accounts.zoho.eu"
        case "in":
            accountsBase = "https://accounts.zoho.in"
        case "com.au", "au":
            accountsBase = "https://accounts.zoho.com.au"
        default:
            accountsBase = "https://accounts.zoho.com"
        }

        let url = URL(string: "\(accountsBase)/oauth/v2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type=authorization_code",
            "client_id=\(clientId)",
            "client_secret=\(clientSecret)",
            "code=\(code)",
            "redirect_uri=\(redirectUri)"
        ]

        request.httpBody = bodyParams.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenRefreshFailed(errorMessage)
        }

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }
}
