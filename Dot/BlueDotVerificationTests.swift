//
//  MockSecureKeys.swift
//  BotDetectionTests
//
//  Created by Alexandre Oliveira Santos on 5/12/21.
//  Copyright © 2021 Walmart. All rights reserved.
//

import Foundation
import WalmartPlatform

public struct MockSecureKeys: SecureKeyProviding {
    public var branchProdKey: String
    public var branchDevKey: String
    public var braze: String
    public var buttonApplicationIdDebug: String
    public var buttonApplicationIdProd: String
    public var pendoKey: String
    public var quantumMetricKey: String
    public var quantumMetricStageKey: String
    public var appsFlyerDevKey: String
    public var appsFlyerAppID: String
    public var appsFlyerOneLinkAuth: String
    public var fitPredictorPartnerKey: String
    public var fitPredictorServiceKey: String
    public var fitPredictorEmailSalt: String
    public var flipp: String
    public var threatMetrixStgOrgID: String
    public var threatMetrixProdOrgID: String
    public var encryptionKey: String
    public var mokePerimeterXKey: String
    public var idMeClientIdKey: String
    public var appCenterKey: String
    public var arAPIClientIdKey: String
    public var arAPIClientSecretKey: String
    public var googleMaps: String
    public var fisPayPageId: String
    public var fisPayPageProdId: String
    public var bazaarvoice: String

    public var tslSharedSecrete: String
    public var tslSharedDevSecrete: String
    public var tslClientKey: String
    public var tslClientDevKey: String
    public var livestreamSaltKey: String
    public var livestreamSaltDevKey: String
    public var aropticalProdKey: String
    public var aropticalDevKey: String
    public var dsgNativePartnerKey: String
    public var dsgNativeAPIServiceKey: String
    public var synchronyStageClientKey: String
    public var synchronyStageClientIDKey: String
    public var synchronyClientKey: String
    public var synchronyClientIDKey: String
    public var synchronyBusinessStageClientKey: String
    public var synchronyBusinessStageClientID: String
    public var synchronyBusinessClientKey: String
    public var synchronyBusinessClientID: String

    public var acousticAppKey: String
    public var acousticClientSecret: String
    public var acousticIgniToken: String
    public var acousticRefreshToken: String

    public var compassProdLoggedInConsumerId: String
    public var compassStageLoggedInConsumerId: String
    public var compassProdGuestConsumerId: String
    public var compassStageGuestConsumerId: String
    public var compassProdGuestClientSecret: String
    public var compassStageGuestClientSecret: String

    public init(
        branchProdKey: String = "branch_prod_key",
        branchDevKey: String = "branch_dev_key",
        braze: String = "braze_key",
        buttonApplicationIdDebug: String = "button_application_id_debug",
        buttonApplicationIdProd: String = "button_application_id_prod",
        pendoKey: String = "pendo_Key",
        perimeterX: String = "perimeterX_key",
        quantumMetricKey: String = "quantumMetric_key",
        quantumMetricStageKey: String = "quantumMetric_stageKey",
        appsFlyerDevKey: String = "appsFlyerDevKey_key",
        appsFlyerAppID: String = "appsFlyerAppID_key",
        appsFlyerOneLinkAuth: String = "appsFlyerOneLinkAuth_key",
        fitPredictorPartnerKey: String = "fitPredictorPartnerKey",
        fitPredictorServiceKey: String = "fitPredictorServiceKey",
        fitPredictorEmailSalt: String = "fitPredictorEmailSalt",
        flipp: String = "flipp_key",
        threatMetrixStgOrgID: String = "1abcd2ef",
        threatMetrixProdOrgID: String = "fe2dcba1",
        encryptionKey: String = "0123456789ABCDEF0123456789ABCDEF",
        idMeClientIdKey: String = "id_me_client_id_key",
        appCenterKey: String = "app_center_key",
        arAPIClientIdKey: String = "arAPIClientId_key",
        arAPIClientSecretKey: String = "arAPIClientSecret_key",
        googleMaps: String = "googleMaps_key",
        fisPaypageId: String = "fisPaypageId",
        fisPayPageProdId: String = "fisPayPageProdId",
        bazaarvoice: String = "bazaarvoice_key",
        tslSharedSecrete: String = "tslSharedSecrete",
        tslSharedDevSecrete: String = "tslSharedDevSecrete",
        tslClientKey: String = "tslClientKey",
        tslClientDevKey: String = "tslClientDevKey",
        livestreamSaltKey: String = "livestreamSaltKey",
        livestreamSaltDevKey: String = "livestreamSaltDevKey",
        aropticalProdKey: String = "aropticalProdKey",
        aropticalDevKey: String = "aropticalDevKey",
        dsgNativePartnerKey: String = "dsgNativePartnerKey",
        dsgNativeAPIServiceKey: String = "dsgNativeAPIServiceKey",
        acousticAppKey: String = "acousticAppKey",
        acousticClientSecret: String = "acousticClientSecret",
        acousticIgniToken: String = "acousticIgniToken",
        acousticRefreshToken: String = "acousticRefreshToken",
        synchronyStageClientKey: String = "synchronyStageClientKey",
        synchronyStageClientIDKey: String = "synchronyStageClientIDKey",
        synchronyClientKey: String = "synchronyClientKey",
        synchronyClientIDKey: String = "synchronyClientIDKey",
        synchronyBusinessStageClientKey: String = "synchronyBusinessStageClientKey",
        synchronyBusinessStageClientID: String = "synchronyBusinessStageClientID",
        synchronyBusinessClientKey: String = "synchronyBusinessClientKey",
        synchronyBusinessClientID: String = "synchronyBusinessClientID",
        compassProdLoggedInConsumerId: String = "compassProdLoggedInConsumerId",
        compassStageLoggedInConsumerId: String = "compassStageLoggedInConsumerId",
        compassProdGuestConsumerId: String = "compassProdGuestConsumerId",
        compassStageGuestConsumerId: String = "compassStageGuestConsumerId",
        compassProdGuestClientSecret: String = "compassProdGuestClientSecret",
        compassStageGuestClientSecret: String = "compassStageGuestClientSecret"
    ) {
        self.branchProdKey = branchProdKey
        self.branchDevKey = branchDevKey
        self.braze = braze
        self.buttonApplicationIdDebug = buttonApplicationIdDebug
        self.buttonApplicationIdProd = buttonApplicationIdProd
        self.pendoKey = pendoKey
        mokePerimeterXKey = perimeterX
        self.quantumMetricKey = quantumMetricKey
        self.quantumMetricStageKey = quantumMetricStageKey
        self.appsFlyerDevKey = appsFlyerDevKey
        self.appsFlyerAppID = appsFlyerAppID
        self.appsFlyerOneLinkAuth = appsFlyerOneLinkAuth
        self.fitPredictorPartnerKey = fitPredictorPartnerKey
        self.fitPredictorServiceKey = fitPredictorServiceKey
        self.fitPredictorEmailSalt = fitPredictorEmailSalt
        self.flipp = flipp
        self.threatMetrixStgOrgID = threatMetrixStgOrgID
        self.threatMetrixProdOrgID = threatMetrixProdOrgID
        self.encryptionKey = encryptionKey
        self.idMeClientIdKey = idMeClientIdKey
        self.appCenterKey = appCenterKey
        self.arAPIClientIdKey = arAPIClientIdKey
        self.arAPIClientSecretKey = arAPIClientSecretKey
        self.googleMaps = googleMaps
        fisPayPageId = fisPaypageId
        self.fisPayPageProdId = fisPayPageProdId
        self.bazaarvoice = bazaarvoice
        self.tslClientKey = tslClientKey
        self.tslClientDevKey = tslClientDevKey
        self.tslSharedSecrete = tslSharedSecrete
        self.tslSharedDevSecrete = tslSharedDevSecrete
        self.livestreamSaltKey = livestreamSaltKey
        self.livestreamSaltDevKey = livestreamSaltDevKey
        self.aropticalProdKey = aropticalProdKey
        self.aropticalDevKey = aropticalDevKey
        self.dsgNativePartnerKey = dsgNativePartnerKey
        self.dsgNativeAPIServiceKey = dsgNativeAPIServiceKey
        self.acousticAppKey = acousticAppKey
        self.acousticClientSecret = acousticClientSecret
        self.acousticIgniToken = acousticIgniToken
        self.acousticRefreshToken = acousticRefreshToken
        self.synchronyStageClientKey = synchronyStageClientKey
        self.synchronyStageClientIDKey = synchronyStageClientIDKey
        self.synchronyClientKey = synchronyClientKey
        self.synchronyClientIDKey = synchronyClientIDKey
        self.synchronyBusinessStageClientKey = synchronyBusinessStageClientKey
        self.synchronyBusinessStageClientID = synchronyBusinessStageClientID
        self.synchronyBusinessClientKey = synchronyBusinessClientKey
        self.synchronyBusinessClientID = synchronyBusinessClientID
        self.compassProdLoggedInConsumerId = compassProdLoggedInConsumerId
        self.compassStageLoggedInConsumerId = compassStageLoggedInConsumerId
        self.compassProdGuestConsumerId = compassProdGuestConsumerId
        self.compassStageGuestConsumerId = compassStageGuestConsumerId
        self.compassProdGuestClientSecret = compassProdGuestClientSecret
        self.compassStageGuestClientSecret = compassStageGuestClientSecret
    }

    public func getPerimeterXKey() -> String {
        return mokePerimeterXKey
    }
}
