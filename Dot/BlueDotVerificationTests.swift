//
//  Environment.swift
//  compass-sample-app
//
//  Created by Pratik Patel on 6/6/24.
//

import Combine
import Foundation
import PluginAPIs
import WalmartPlatform

enum TokenType: String {
    case glass
}

enum GlassAuthType: String, CaseIterable, Identifiable {
    case loggedIn = "Logged In"
    case guest = "Guest"
    var id: String { rawValue }
}

final class EnvironmentStore: ObservableObject {
    static let shared = EnvironmentStore()

    @Published var backendEnv: CompassEnvironment = .staging
    @Published var mockUser = true
    @Published var tokenType: TokenType = .glass
    @Published var initialStore = 2119
    @Published var accountID = "988sdd-erer-43434"
    @Published var glassAuthType: GlassAuthType = .loggedIn

    private init() {}
}

enum Environment {
    private static var store: EnvironmentStore { EnvironmentStore.shared }

    static var backendEnv: CompassEnvironment {
        get { store.backendEnv }
        set { store.backendEnv = newValue }
    }

    static var mockUser: Bool {
        get { store.mockUser }
        set { store.mockUser = newValue }
    }

    static var tokenType: TokenType {
        get { store.tokenType }
        set { store.tokenType = newValue }
    }

    static var glassAuthType: GlassAuthType {
        get { store.glassAuthType }
        set { store.glassAuthType = newValue }
    }

    static var initialStore: Int {
        get { store.initialStore }
        set { store.initialStore = newValue }
    }

    static var accountID: String {
        get { store.accountID }
        set { store.accountID = newValue }
    }

    // static func authParmeter(using secureKeys: SecureKeyProviding) -> CompassAuthParameter {
    //     guard glassAuthType == .loggedIn else {
    //         // Guest Glass user - no CID/SPID, uses clientSecret
    //         let (consumerID, visitorID) = backendEnv == .production
    //             ? (
    //                 "6032c31d-55fc-4f1a-abb7-76246301c2c3",
    //                 "glass_visitorId"
    //             )
    //             : (
    //                 "c061c52a-b978-4ae9-9875-6584e58e8a74",
    //                 "glass_visitorId"
    //             )
    //         return CompassAuthParameter(
    //             clientSecret: backendEnv == .production
    //                 ? secureKeys.compassProdGuestClientSecret
    //                 : secureKeys.compassStageGuestClientSecret,
    //             tokenType: tokenType.rawValue,
    //             accountID: visitorID,
    //             consumerID: consumerID,
    //             env: backendEnv,
    //             anonymizedUserId: visitorID,
    //             tenantId: "elh9ie"
    //         )
    //     }

    static func getConfiguration(for site: Int) -> CompassClientConfiguration {
        CompassClientConfiguration(
            environment: .staging,
            country: "US",
            site: site,
            userId: accountID,
            siteType: .Store,
            mockUser: mockUser,
            businessUnitType: .WALMART
        )
    }
}

enum DebugData {
    enum StoreID {
        static let inStore = "3594"
        static let oriient = "2119"
    }

    static let testCompassEventStatus = CurrentValueSubject<Int, Never>(1)
    static let count = 1
    static let sensorAssetId = "3452000"
    static let asset2280List = ["1645190"]
    static let asset3594List = ["836445", "836446", "2712934", "2556484"]

    static let assetNodFound = "2670713"
    static let otherStore = "585879"

    static let inStoreMapEncodedString = "eHMvW1pKLEFHXS8x"
    static let oriientMapEncodedString = "WkovWy0xQ2wsMTddLzE="
    static let inStoreMapMultipinEncodedString = "eHMvWy1GQixGYyMtSXAsRW1dLzE="
    static let oriientMapMultipinEncodedString = "YzAvWy1GQyxGZCMtSXEsRW1dLzE="
}

extension Dictionary {
    func toJSONString() -> String? {
        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: self,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        else {
            // Log.debug("Something is wrong while converting dictionary to JSON data.")
            return nil
        }

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            // Log.debug("Something is wrong while converting JSON data to JSON string.")
            return nil
        }

        return jsonString
    }
}
