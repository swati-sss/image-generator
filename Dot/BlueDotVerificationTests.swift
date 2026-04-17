//
//  WalmartKeys.swift
//  Walmart
//
//  Created by Alexandre Oliveira Santos on 5/4/21.
//  Copyright © 2021 Walmart. All rights reserved.
//

import Foundation
import WalmartPlatform

/// This represents the actual secure keys used by the Walmart app
struct WalmartKeys: SecureKeyProviding {
    let braze = kBrazeAPIKey
    let pendoKey = "not-needed"
    let quantumMetricKey = kQuantumMetricKey
    let quantumMetricStageKey = kQuantumMetricStageKey
    let appsFlyerDevKey = kAppsFlyerDevKey
    let appsFlyerAppID = kAppsFlyerAppID
    let appsFlyerOneLinkAuth = kAppsFlyerOneLinkAuth
    let flipp = kFlippAPIKey
    let threatMetrixStgOrgID = kThreatMetrixStgOrgID
    let threatMetrixProdOrgID = kThreatMetrixProdOrgID
    let fitPredictorPartnerKey = kFitPredictorPartnerKey
    let fitPredictorServiceKey = kFitPredictorServiceKey
    let fitPredictorEmailSalt = kFitPredictorEmailSalt
    let encryptionKey = kEncryptionKey
    let idMeClientIdKey = kIdMeClientIdKey
    let appCenterKey = kAppCenterAPIKey
    let arAPIClientSecretKey = kArAPIClientSecretKey
    let arAPIClientIdKey = kArAPIClientIdKey
    let googleMaps = "not-needed"
    let fisPayPageId = kFisPaypageIDKey
    let fisPayPageProdId = kFisPaypageIDProdKey
    let bazaarvoice = kBazaarvoiceLicenceKey
    let tslSharedSecrete = ktslSharedSecrete
    let tslSharedDevSecrete = ktslSharedDevSecrete
    let tslClientKey = ktslClientKey
    let tslClientDevKey = ktslClientDevKey
    let livestreamSaltKey = kLivestreamSaltKey
    let livestreamSaltDevKey = klivestreamSaltDevKey
    let aropticalProdKey = karopticalProdKey
    let aropticalDevKey = karopticalDevKey
    let dsgNativePartnerKey = kDSGNativePartnerKey
    let dsgNativeAPIServiceKey = kDSGNativeAPIServiceKey
    let synchronyStageClientKey = "not-needed"
    let synchronyStageClientIDKey = "not-needed"
    let synchronyClientKey = "not-needed"
    let synchronyClientIDKey = "not-needed"
    let synchronyBusinessStageClientKey = "not-needed"
    let synchronyBusinessStageClientID = "not-needed"
    let synchronyBusinessClientKey = "not-needed"
    let synchronyBusinessClientID = "not-needed"
    let compassProdLoggedInConsumerId = kCompassProdLoggedInConsumerIdKey
    let compassStageLoggedInConsumerId = kCompassStageLoggedInConsumerIdKey
    let compassProdGuestConsumerId = kCompassProdGuestConsumerIdKey
    let compassStageGuestConsumerId = kCompassStageGuestConsumerIdKey
    let compassProdGuestClientSecret = kCompassProdGuestClientSecretKey
    let compassStageGuestClientSecret = kCompassStageGuestClientSecretKey
    /// DO NOT REMOVE: Only a decoy, please check docs/security/deceptions.md for more details.
    let supportSecrets = SupportSecrets()

    /// Container
    let container: Container

    init(container: Container) {
        self.container = container
    }

    func getPerimeterXKey() -> String {
        let environmentAPI: EnvironmentAPI = container.get()

        guard environmentAPI.currentEnvironment.isProduction else {
            return kPerimeterXAPIDebugKey
        }

        return kPerimeterXAPIKey
    }
}
