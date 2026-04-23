//
//  Compass+Debug.swift
//  compass_sdk_ios
//
//  Created by Pratik Patel on 11/18/25.
//

import Foundation

#if DEBUG

enum CompassDebugOverrides {
    static var localMapURL: URL?
}

extension Compass {
    private enum AssociatedKeys {
        static var originalStoreConfig = "originalStoreConfig"
        static var originalConsumerConfig = "originalConsumerConfig"
        static var hasAppliedOverrides = "hasAppliedOverrides"
    }

    public func setStore(_ store: Int?) {
        self.currentStore = store
    }

    private var originalStoreConfig: StoreConfig? {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.originalStoreConfig) as? StoreConfig
        }
        set {
            objc_setAssociatedObject( self,
                                      AssociatedKeys.originalStoreConfig,
                                      newValue,
                                      .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var hasAppliedOverrides: Bool {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.hasAppliedOverrides) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     AssociatedKeys.hasAppliedOverrides,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var originalConsumerConfig: [String: Bool]? {
        get {
            objc_getAssociatedObject(self, AssociatedKeys.originalConsumerConfig) as? [String: Bool]
        }
        set {
            objc_setAssociatedObject(self,
                                     AssociatedKeys.originalConsumerConfig,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var currentConsumerConfig: [String: Bool] {
        [
            "isMapCdnEnabled": Analytics.isMapCdnEnabled,
            "isMapCompressionEnabled": Analytics.isMapCompressionEnabled
        ]
    }

    public func getCurrentStoreConfig() -> [String: Any]? {
        guard let assetService = serviceLocator.getAssetService() as? AssetServiceImpl,
              let storeConfig = assetService.lastStoreConfig else { return nil }

        var config: [String: Any] = [:]

        config["bluedotEnabled"] = storeConfig.bluedotEnabled ?? false
        config["bluedotDisplayed"] = storeConfig.bluedotDisplayed ?? false
        config["dynamicMapEnabled"] = storeConfig.dynamicMapEnabled ?? false
        config["zoomControlEnabled"] = storeConfig.zoomControlEnabled ?? false
        config["errorScreensEnabled"] = storeConfig.errorScreensEnabled ?? false
        config["dynamicMapRotationEnabled"] = storeConfig.dynamicMapRotationEnabled ?? false
        config["spinnerEnabled"] = storeConfig.spinnerEnabled ?? false
        config["useBackgroundService"] = storeConfig.useBackgroundService ?? false
        config["heartbeatInLocation"] = storeConfig.heartbeatInLocation ?? false
        config["heartbeatEnabled"] = storeConfig.heartbeatEnabled ?? false
        config["heartBeatInUser"] = storeConfig.heartBeatInUser ?? false
        config["navigationEnabled"] = storeConfig.navigationEnabled ?? false
        config["valid"] = storeConfig.valid ?? false
        config["analytics"] = storeConfig.analytics ?? false

        config["backgroundServiceTimeout"] = storeConfig.backgroundServiceTimeout ?? 300.0
        config["geoFenceCheckTimeout"] = storeConfig.geoFenceCheckTimeout ?? 1.0
        config["positioningSessionTimeout"] = storeConfig.positioningSessionTimeout ?? 1.0
        config["sessionRefreshTime"] = storeConfig.sessionRefreshTime ?? SessionTime.positionRefreshTime
        config["heartbeatInterval"] = storeConfig.heartbeatInterval ?? 300_000.0
        config["batchInterval"] = storeConfig.batchInterval ?? 60_000.0

        config["supportedEventList"] = storeConfig.supportedEventList ?? ""
        config["storeId"] = storeConfig.storeId ?? 0
        config["mapType"] = storeConfig.mapType ?? ""

        let offsetConfig = storeConfig.offset ?? StoreConfigOffset(x: 0, y: 0)
        config["offset"] = [
            "x": Double(offsetConfig.x),
            "y": Double(offsetConfig.y)
        ]

        let navigationConfig = storeConfig.navigation ?? NavigationConfig()
        config["navigation"] = [
            "enabled": navigationConfig.enabled ?? (storeConfig.navigationEnabled ?? false),
            "refreshDuration": navigationConfig.refreshDuration ?? 0.0,
            "isAutomaticNavigation": navigationConfig.isAutomaticNavigation
        ]

        let mapUiConfig = storeConfig.mapUi ?? MapUiConfig()
        config["mapUi"] = [
            "bannerEnabled": mapUiConfig.bannerEnabled,
            "snackBarEnabled": mapUiConfig.snackBarEnabled,
            "pinLocationUnavailableBannerEnabled": mapUiConfig.pinLocationUnavailableBannerEnabled
        ]

        let pinsConfig = storeConfig.resolvedPins
        config["pins"] = [
            "featurePinEnabled": pinsConfig.featurePinEnabled,
            "pinType": pinsConfig.pinType,
            "groupPinsEnabled": pinsConfig.groupPinsEnabled
        ]

        let debugLogConfig = storeConfig.resolvedDebugLog
        config["debugLog"] = [
            "sensitiveInfoEnabled": debugLogConfig.sensitiveInfoEnabled,
            "navigationValidateCoordEnabled": debugLogConfig.navigationValidateCoordEnabled
        ]

        config["consumerConfig"] = currentConsumerConfig

        return config
    }

    public func applyFeatureFlagOverrides(_ overrides: [String: Any]) {
        guard let assetService = serviceLocator.getAssetService() as? AssetServiceImpl,
              var storeConfig = assetService.lastStoreConfig else { return }

        if !hasAppliedOverrides {
            originalStoreConfig = storeConfig
            originalConsumerConfig = currentConsumerConfig
            hasAppliedOverrides = true
        }

        applyBooleanOverrides(overrides, to: &storeConfig)
        applyDoubleOverrides(overrides, to: &storeConfig)
        applyIntegerOverrides(overrides, to: &storeConfig)
        applyStringOverrides(overrides, to: &storeConfig)
        applyNestedOverrides(overrides, to: &storeConfig)

        assetService.lastStoreConfig = storeConfig
        _ = viewModel.updateStoreConfiguration(storeConfig)
    }

    private func applyBooleanOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        let mappings: [String: WritableKeyPath<StoreConfig, Bool?>] = [
            "bluedotEnabled": \.bluedotEnabled,
            "bluedotDisplayed": \.bluedotDisplayed,
            "dynamicMapEnabled": \.dynamicMapEnabled,
            "zoomControlEnabled": \.zoomControlEnabled,
            "errorScreensEnabled": \.errorScreensEnabled,
            "dynamicMapRotationEnabled": \.dynamicMapRotationEnabled,
            "spinnerEnabled": \.spinnerEnabled,
            "useBackgroundService": \.useBackgroundService,
            "heartbeatInLocation": \.heartbeatInLocation,
            "heartbeatEnabled": \.heartbeatEnabled,
            "heartBeatInUser": \.heartBeatInUser,
            "navigationEnabled": \.navigationEnabled,
            "valid": \.valid,
            "analytics": \.analytics
        ]

        for (key, keyPath) in mappings {
            if let value = boolValue(overrides[key]) {
                storeConfig[keyPath: keyPath] = value
            }
        }
    }

    private func applyDoubleOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        let mappings: [String: WritableKeyPath<StoreConfig, Double?>] = [
            "backgroundServiceTimeout": \.backgroundServiceTimeout,
            "geoFenceCheckTimeout": \.geoFenceCheckTimeout,
            "positioningSessionTimeout": \.positioningSessionTimeout,
            "heartbeatInterval": \.heartbeatInterval,
            "batchInterval": \.batchInterval
        ]

        for (key, keyPath) in mappings {
            if let value = doubleValue(overrides[key]) {
                storeConfig[keyPath: keyPath] = value
            }
        }
    }

    private func applyIntegerOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        let mappings: [String: WritableKeyPath<StoreConfig, Int?>] = [
            "sessionRefreshTime": \.sessionRefreshTime,
            "storeId": \.storeId
        ]

        for (key, keyPath) in mappings {
            if let value = intValue(overrides[key]) {
                storeConfig[keyPath: keyPath] = value
            }
        }
    }

    private func applyStringOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        if let mapType = overrides["mapType"] as? String {
            storeConfig.mapType = mapType
        }
        if let supportedEventList = overrides["supportedEventList"] as? String {
            storeConfig.supportedEventList = supportedEventList
        }
    }

    private func applyNestedOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        if let offsetOverrides = overrides["offset"] as? [String: Any] {
            applyOffsetOverrides(offsetOverrides, to: &storeConfig)
        }
        if let navigationOverrides = overrides["navigation"] as? [String: Any] {
            applyNavigationOverrides(navigationOverrides, to: &storeConfig)
        }
        if let mapUiOverrides = overrides["mapUi"] as? [String: Any] {
            applyMapUiOverrides(mapUiOverrides, to: &storeConfig)
        }
        if let pinsOverrides = overrides["pins"] as? [String: Any] {
            applyPinsOverrides(pinsOverrides, to: &storeConfig)
        }
        if let debugLogOverrides = overrides["debugLog"] as? [String: Any] {
            applyDebugLogOverrides(debugLogOverrides, to: &storeConfig)
        }
        if let consumerConfigOverrides = overrides["consumerConfig"] as? [String: Any] {
            applyConsumerConfigOverrides(consumerConfigOverrides)
        }
    }

    private func applyOffsetOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        var offsetConfig = storeConfig.offset ?? StoreConfigOffset(x: 0, y: 0)

        if let x = doubleValue(overrides["x"]) {
            offsetConfig.x = CGFloat(x)
        }
        if let y = doubleValue(overrides["y"]) {
            offsetConfig.y = CGFloat(y)
        }

        storeConfig.offset = offsetConfig
    }

    private func applyNavigationOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        var navigationConfig = storeConfig.navigation ?? NavigationConfig()

        if let enabled = boolValue(overrides["enabled"]) {
            navigationConfig.enabled = enabled
            storeConfig.navigationEnabled = enabled
        }
        if let refreshDuration = doubleValue(overrides["refreshDuration"]) {
            navigationConfig.refreshDuration = refreshDuration
        }
        if let isAutomaticNavigation = boolValue(overrides["isAutomaticNavigation"]) {
            navigationConfig.isAutomaticNavigation = isAutomaticNavigation
        }

        storeConfig.navigation = navigationConfig
    }

    private func applyMapUiOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        var mapUiConfig = storeConfig.mapUi ?? MapUiConfig()

        if let bannerEnabled = boolValue(overrides["bannerEnabled"]) {
            mapUiConfig.bannerEnabled = bannerEnabled
        }
        if let snackBarEnabled = boolValue(overrides["snackBarEnabled"]) {
            mapUiConfig.snackBarEnabled = snackBarEnabled
        }
        if let pinLocationUnavailableBannerEnabled =
            boolValue(overrides["pinLocationUnavailableBannerEnabled"]) {
            mapUiConfig.pinLocationUnavailableBannerEnabled = pinLocationUnavailableBannerEnabled
        }

        storeConfig.mapUi = mapUiConfig
    }

    private func applyPinsOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        var pinsConfig = storeConfig.resolvedPins

        if let featurePinEnabled = boolValue(overrides["featurePinEnabled"]) {
            pinsConfig.featurePinEnabled = featurePinEnabled
        }
        if let pinType = overrides["pinType"] as? String {
            pinsConfig.pinType = pinType
        }
        if let groupPinsEnabled = boolValue(overrides["groupPinsEnabled"]) {
            pinsConfig.groupPinsEnabled = groupPinsEnabled
        }

        storeConfig.pins = pinsConfig
    }

    private func applyDebugLogOverrides(_ overrides: [String: Any], to storeConfig: inout StoreConfig) {
        var debugLogConfig = storeConfig.resolvedDebugLog

        if let sensitiveInfoEnabled = boolValue(overrides["sensitiveInfoEnabled"]) {
            debugLogConfig.sensitiveInfoEnabled = sensitiveInfoEnabled
        }
        if let navigationValidateCoordEnabled = boolValue(overrides["navigationValidateCoordEnabled"]) {
            debugLogConfig.navigationValidateCoordEnabled = navigationValidateCoordEnabled
        }

        storeConfig.debugLog = debugLogConfig
    }

    private func applyConsumerConfigOverrides(_ overrides: [String: Any]) {
        if let isMapCdnEnabled = boolValue(overrides["isMapCdnEnabled"]) {
            Analytics.isMapCdnEnabled = isMapCdnEnabled
        }
        if let isMapCompressionEnabled = boolValue(overrides["isMapCompressionEnabled"]) {
            Analytics.isMapCompressionEnabled = isMapCompressionEnabled
        }
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    public func revertToOriginalConfig() {
        guard let originalConfig = originalStoreConfig,
              let assetService = serviceLocator.getAssetService() as? AssetServiceImpl else { return }

        assetService.lastStoreConfig = originalConfig
        _ = viewModel.updateStoreConfiguration(originalConfig)

        if let originalConsumerConfig {
            Analytics.isMapCdnEnabled = originalConsumerConfig["isMapCdnEnabled"] ?? false
            Analytics.isMapCompressionEnabled = originalConsumerConfig["isMapCompressionEnabled"] ?? false
        }

        hasAppliedOverrides = false
        originalStoreConfig = nil
        originalConsumerConfig = nil
    }

    public func hasOverridesApplied() -> Bool {
        return hasAppliedOverrides
    }

    public func resetOverrideTracking() {
        hasAppliedOverrides = false
        originalStoreConfig = nil
        originalConsumerConfig = nil
    }

    public func setLocalMapFileURL(_ url: URL?) {
        Compass.setLocalMapFileURL(url)
    }

    public static func setLocalMapFileURL(_ url: URL?) {
        CompassDebugOverrides.localMapURL = url
    }

    public static func currentLocalMapFileURL() -> URL? {
        CompassDebugOverrides.localMapURL
    }
}
#endif
