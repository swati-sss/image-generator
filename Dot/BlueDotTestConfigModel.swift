// MARK: - BlueDot Test Configuration

import compass_sdk_ios

private enum BlueDotAuthTokenType: String {
    case iam
    case pingfed
    case user

    init(rawConfigValue: String) {
        switch rawConfigValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "iam":
            self = .iam
        case "pingfed":
            self = .pingfed
        case "user":
            self = .user
        default:
            self = .user
        }
    }
}

struct BlueDotTestConfig: Codable {
    let testStores: [Int]
    let testEnvironment: String
    let mockUserEnabled: Bool
    let tokenType: String
    let verificationTimeout: Int
    let accountID: String
    let flagsToCheck: [String: Bool]

    func getEnabledFlags() -> [String] {
        flagsToCheck.compactMap { key, value in
            value ? key : nil
        }
    }

    func isFlagEnabled(_ flagName: String) -> Bool {
        flagsToCheck[flagName] ?? false
    }

    var authToken: String {
        switch normalizedTokenType {
        case .user:
            return "MTAyOTYyMDE4dSxyrP0t1Jm+zsHDj/m58lYEBSWPPQT0ASxP67P/p/R/XCviMJx6YIyuweMm/D4szCyTMBgQUr8MJWMSm3S2rqgF8Z3ooqOrbfBJzORYy7wGmKcywYDpRHb13NVCvU9dVoZ2h67qtmWCX5xnAS95ZSpQBIV+q5odNqvzV1gAYlvCveWZ0+3rq3ePWs9LhzZ7tXoVX6MbrQS+QrPDOp+Ee8FAqtMt7lzQdJSvbzFlrGCMSMVOB6MAabmTP67qQX6SO9FaZQ9xSvIHt7THYc5BH11KK3aFtE5QbXB6Vt5ZAzN3ltf8skOawMmpueLResLhye4vrf8JNA1nW1zzpx3kxQ=="
        case .pingfed:
            return "eyJhbGciOiJSUzI1NiIsImtpZCI6InBmZWRzdGFnZV9zaWduX01heTIwMjUiLCJwaS5hdG0iOiIzIn0.eyJzY29wZSI6Im9wZW5pZCBmdWxsIiwiYXV0aG9yaXphdGlvbl9kZXRhaWxzIjpbXSwiY2xpZW50X2lkIjoiR0lGMkFQUCIsImd1aWQiOiJFN2QyVnpyR3JTa1Zha2ZVY25sdUF6U0JEM25XUnlYTiIsImlzcyI6Imh0dHBzOi8vcGZlZGNlcnQud2FsLW1hcnQuY29tIiwianRpIjoickZvMElEeFYiLCJhdWQiOiJHSUYyQVBQIiwic3ViIjoiYjBwMDd2NkBob21lb2ZmaWNlLndhbC1tYXJ0LmNvbSIsInVwbiI6ImIwcDA3djZAaG9tZW9mZmljZS53YWwtbWFydC5jb20iLCJuYmYiOjE3MzcxMzQzNjMsImlhdCI6MTczNzEzNDQ4MywidXNlcmlkIjoiYjBwMDd2NiIsIndpbiI6IjIzMDIxMDQyMCIsImV4cCI6MTczNzE3NzY4M30.AOJ7bM7mwNm79zZ0Z_7-HnbeVznAiLLMMba24pzimmGJACR8skMKzoEYFfqZWf_4Ovj2EAjqJMlLZhyp0H1u_Y3KELWpZ-MCwD0ngp6mM84y2KWhk8HszJFAcnTIeEr151sdnRWYLqQm12qIWQ_oJy7PCzqGbHswr262WksgLu_bOTZuS1wph8wT16uq1b3ixp2NeDF8nT3O1hqf_KkZcN5hiZbjgWBvrD5h86s72hOWQdMh6mUzDD8BS-sE5pWCoR9U7BatBrqBkG92KP6DWVuzVrB2F_1xriZFwhn4b69hTHOR_HNCNPPrDri6P3MWCZvH9yFkmMhjgUJsmF_GOksoeCnWZdu6kfIgJXT2aHsjUdKURH2sZvwMJZpFkU-dqEXOgE61suunvXdKTcwSFEjwVEPQcKds1nFsUrXk_k-4q6o_W1_zgTgXg7btw6iAM0Jr928w4GsdcZXtZyCDzGPR1WwYHVI1XHQ2zmGKWIEDwFSZJNecLEvlzz2xQ52Y28s1aRwjlrP3fu3IS_gGI-D2_uh0Q-1LvFFTD06i38P7oYtYAgVqDlHiuVrZOIlvDmQpeImXx1O5CkGYQhXjxqt4cRCzhcPV-Di7C74K92hMxavuWxH6OwSagWl3mLSh2nwi1pL-aBATpAcW-OcRpgOZ08qSDrd0BdW2vQidnAM"
        case .iam:
            return isProductionEnvironment ? "T3u0ATKtG2Sz3cOOZGnWmDS3AXC7JoOn8I39nxdB-XeCoR1hN1g61dHySkqwCuqm2jQvYDp4UfoAdENPxu_e5g" : "Uhcqt1EBCq3COum7WhGK4b0Pre0TyMndfqMsCslnzyd70Zc5Xy1NI-pyCARRNG0qQvkI2iVv2s7sKGBiTwz_PQ"
        }
    }

    var consumerID: String {
        switch normalizedTokenType {
        case .user:
            return isProductionEnvironment ? "069B60DB-4E9C-45B5-AD25-E475C9A0DB7A" : "573e4372-b4f0-4f01-a58d-3f7aff19e078"
        case .pingfed:
            return isProductionEnvironment ? "069B60DB-4E9C-45B5-AD25-E475C9A0DB7A" : "87ef92cb-d52c-4462-b4f7-d2f58046d9c6"
        case .iam:
            return isProductionEnvironment ? "6032c31d-55fc-4f1a-abb7-76246301c2c3" : "c061c52a-b978-4ae9-9875-6584e58e8a74"
        }
    }

    var apiEndpoint: String {
        isProductionEnvironment
            ? "https://developer.api.us.walmart.com/api-proxy/service/COMPASS/SERVICE/v1/config"
            : "https://developer.api.us.stg.walmart.com/api-proxy/service/COMPASS/SERVICE/v1/config"
    }

    var compassEnvironment: CompassEnvironment {
        isProductionEnvironment ? .production : .staging
    }

    var normalizedTokenTypeString: String {
        normalizedTokenType.rawValue
    }

    var authParameter: AuthParameter {
        AuthParameter(
            clientSecret: authToken,
            tokenType: normalizedTokenTypeString,
            accountID: accountID,
            consumerID: consumerID
        )
    }

    private var normalizedTokenType: BlueDotAuthTokenType {
        BlueDotAuthTokenType(rawConfigValue: tokenType)
    }

    private var isProductionEnvironment: Bool {
        let environment = testEnvironment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return environment == "prod" || environment == "production"
    }
}
