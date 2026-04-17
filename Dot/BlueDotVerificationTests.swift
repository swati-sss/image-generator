//
//  APIKeys.swift
//  WalmartPlatform
//
//  Created by Venkatesh Jujjavarapu on 01/12/20.
//  Copyright © 2020 Walmart. All rights reserved.
//

import Foundation

// MARK: - This file acts as the storage for all the keys for API's in Glass App moving forward.

/// Provides all the keys used by all services.
public protocol SecureKeyProviding {
    var airshipKey: String { get }
    var airshipSecret: String { get }
    var branchProdKey: String { get }
    var branchDevKey: String { get }
    var braze: String { get }
    var buttonApplicationIdDebug: String { get }
    var buttonApplicationIdProd: String { get }
    var pendoKey: String { get }
    var quantumMetricKey: String { get }
    var quantumMetricStageKey: String { get }
    var appsFlyerDevKey: String { get }
    var appsFlyerAppID: String { get }
    var appsFlyerOneLinkAuth: String { get }
    var fitPredictorPartnerKey: String { get }
    var fitPredictorServiceKey: String { get }
    var fitPredictorEmailSalt: String { get }
    var flipp: String { get }
    var threatMetrixStgOrgID: String { get }
    var threatMetrixProdOrgID: String { get }
    var encryptionKey: String { get }
    var idMeClientIdKey: String { get }
    var appCenterKey: String { get }
    var arAPIClientIdKey: String { get }
    var arAPIClientSecretKey: String { get }
    var googleMaps: String { get }
    var fisPayPageId: String { get }
    var fisPayPageProdId: String { get }
    var bazaarvoice: String { get }
    var tslSharedSecrete: String { get }
    var tslSharedDevSecrete: String { get }
    var tslClientKey: String { get }
    var tslClientDevKey: String { get }
    var livestreamSaltKey: String { get }
    var livestreamSaltDevKey: String { get }
    var acousticAppKey: String { get }
    var acousticClientSecret: String { get }
    var acousticIgniToken: String { get }
    var acousticRefreshToken: String { get }
    var aropticalProdKey: String { get }
    var aropticalDevKey: String { get }
    var dsgNativePartnerKey: String { get }
    var dsgNativeAPIServiceKey: String { get }
    var synchronyStageClientKey: String { get }
    var synchronyStageClientIDKey: String { get }
    var synchronyClientKey: String { get }
    var synchronyClientIDKey: String { get }
    var synchronyBusinessStageClientKey: String { get }
    var synchronyBusinessStageClientID: String { get }
    var synchronyBusinessClientKey: String { get }
    var synchronyBusinessClientID: String { get }
    var compassProdLoggedInConsumerId: String { get }
    var compassStageLoggedInConsumerId: String { get }
    var compassProdGuestConsumerId: String { get }
    var compassStageGuestConsumerId: String { get }
    var compassProdGuestClientSecret: String { get }
    var compassStageGuestClientSecret: String { get }
    var sfmcMID: String { get }
    var sfmcAppId: String { get }
    var sfmcAccessToken: String { get }
    func getPerimeterXKey() -> String
}

extension SecureKeyProviding {
    public var airshipKey: String { "AirshipAPIKey" }
    public var airshipSecret: String { "AirshipAPISecret" }
    public var appCenterKey: String { "AppCenterKey" }
    public var arAPIClientIdKey: String { "ArAPIClientIdKey" }
    public var arAPIClientSecretKey: String { "ArAPIClientSecretKey" }
    public var branchProdKey: String { "BranchProdKey" }
    public var branchDevKey: String { "BranchDevKey" }
    public var buttonApplicationIdDebug: String { "ButtonApplicationIdDebug" }
    public var buttonApplicationIdProd: String { "ButtonApplicationIdProd" }
    public var compassProdLoggedInConsumerId: String { "CompassProdLoggedInConsumerId" }
    public var compassStageLoggedInConsumerId: String { "CompassStageLoggedInConsumerId" }
    public var compassProdGuestConsumerId: String { "CompassProdGuestConsumerId" }
    public var compassStageGuestConsumerId: String { "CompassStageGuestConsumerId" }
    public var compassProdGuestClientSecret: String { "CompassProdGuestClientSecret" }
    public var compassStageGuestClientSecret: String { "CompassStageGuestClientSecret" }
}

/// Acoustic
extension SecureKeyProviding {
    public var acousticAppKey: String { "AcousticAppKey" }
    public var acousticClientSecret: String { "AcousticClientSecret" }
    public var acousticIgniToken: String { "AcousticIgniToken" }
    public var acousticRefreshToken: String { "AcousticRefreshToken" }
}

extension SecureKeyProviding {
    public var aropticalProdKey: String { "AROpticalProdKey" }
    public var aropticalDevKey: String { "AROpticalDevKey" }
}

extension SecureKeyProviding {
    public var sfmcMID: String { "SfmcAPIMID" }
    public var sfmcAppId: String { "SfmcAppId" }
    public var sfmcAccessToken: String { "SfmcAccessToken" }
}

extension SecureKeyProviding {
    public var synchronyBusinessStageClientKey: String { "SynchronyBusinessStageClientKey" }
    public var synchronyBusinessStageClientID: String { "SynchronyBusinessStageClientID" }
    public var synchronyBusinessClientKey: String { "SynchronyBusinessClientKey" }
    public var synchronyBusinessClientID: String { "SynchronyBusinessClientID" }
}
