//
//  CompassPluginAPI.swift
//  Compass
//
//  Created by Platform Team on 12/12/2025.
//  Copyright © 2025 Walmart. All rights reserved.
//

import Combine
import compass_sdk_ios
import PluginAPIs
import UIKit
import WalmartPlatform

public class CompassPluginAPI: CompassAPI {
    private let container: Container

    private var compass: Compass
    private var eventEmitterHandler: ((CompassEventEmitter) -> Void)?
    private var mapInteractionOnPinClick: ((CompassClickedPin) -> Void)?
    private var mapInteractionOnZoomClick: ((Bool, Int) -> Void)?
    private var compassStateOnMapLoaded: ((String) -> Void)?
    private var compassStateOnError: ((String, String) -> Void)?
    private var displayPinsErrorHandler: ((String, String) -> Void)?
    private var isEventEmitterHandlerInstalled = false
    private let poiClickedSubject = PassthroughSubject<CompassPointOfInterestClicked, Never>()
    private var cancellable = Set<AnyCancellable>()
    private var updateAuthParamsCancellable: AnyCancellable?

    public var selectedFloorPublisher: AnyPublisher<Int, Never> {
        compass.selectedFloorPublisher
    }

    public var state: AnyPublisher<PluginAPIs.CompassState, Never> {
        compass.state
            .map { CompassState(from: $0) }
            .eraseToAnyPublisher()
    }

    public var webViewMessagePublisher: AnyPublisher<String, Never> {
        compass.webViewMessagePublisher
    }

    public var poiClickedPublisher: AnyPublisher<CompassPointOfInterestClicked, Never> {
        poiClickedSubject.eraseToAnyPublisher()
    }

    public init(container: Container) {
        self.container = container
        compass = Compass()
    }

    private enum Constant {
        static let tokenType = "glass"
        static let tenantId = "elh9ie"
    }

    // MARK: - Core SDK Initialization

    /// **Initializes the Compass SDK** - Must be called first before using any other Compass functionality.
    ///
    /// This method sets up the Compass SDK with the provided authentication credentials and configuration settings,
    /// then returns a UIViewController containing the map view.
    ///
    /// - Parameters:
    ///   - authParameter: Authentication credentials including client secret, token type, account ID,
    ///                    consumer ID, environment, and user identifiers.
    ///   - configuration: Configuration settings for the map including country, site, user preferences,
    ///                    and feature flags (e.g., manual pin drop, search bar, location ingestion).
    ///   - customMapRequest: Optional custom URLRequest for loading a specific map.
    ///   - completion: Callback invoked with the UIViewController containing the map view when initialization succeeds.
    ///   - onError: Callback invoked with an Error when initialization fails.
    public func initialize(configuration: CompassClientConfiguration, customMapSource: CompassCustomMapSource?) {
        let env = compass_sdk_ios.CompassEnvironment(rawValue: configuration.environment.rawValue) ?? .staging
        let sdkAuth: AuthParameter = createAuthParams(env: env)
        let sdkConfig = Configuration(from: configuration)

        var mapSource: CustomMapSource?
        if let customMapSource {
            mapSource = CustomMapSource(from: customMapSource)
        }

        installEventEmitterHandlerIfNeeded()
        compass.initialize(authParameter: sdkAuth, configuration: sdkConfig, customMapSource: mapSource)
        updateAuthParamsWhenNeeded(env: env)

        webViewMessagePublisher.sink { [weak self] message in
            guard let data = message.data(using: .utf8, allowLossyConversion: true) else {
                return
            }
            do {
                let decoder = JSONDecoder()
                let messageResponse = try decoder.decode(CompassMessageResponse.self, from: data)
                switch messageResponse {
                case .pointOfInterestClicked(let poiClickedInfo):
                    self?.poiClickedSubject.send(poiClickedInfo)
                }
            } catch {
                Log.warning("Unable to decode MapView Message, error: \(error)")
            }
        }
        .store(in: &cancellable)
    }

    // MARK: - Event Tracking

    /// **Records an analytics event** - Track user interactions and behaviors with namespace, type, value, and
    /// metadata.
    ///
    /// - Parameters:
    ///   - namespace: The namespace for the event.
    ///   - eventType: The type of event being recorded.
    ///   - eventValue: The value associated with the event.
    ///   - metaData: Optional dictionary containing additional metadata for the event.
    public func updateEventList(namespace: String, eventType: String, eventValue: String, metaData: [String: Any]?) {
        compass.updateEventList(namespace: namespace, eventType: eventType, eventValue: eventValue, metaData: metaData)
    }

    /// **Updates a Compass event** - Record an event using a structured CompassEvent object.
    ///
    /// - Parameter compassEvent: The CompassEvent containing event type, value, and metadata.
    public func updateEvent(compassEvent: PluginAPIs.CompassEvent) {
        let sdkEvent = compass_sdk_ios.CompassEvent(
            eventType: compassEvent.eventType,
            eventValue: compassEvent.eventValue,
            eventMetadata: compassEvent.eventMetadata
        )
        compass.updateEvent(compassEvent: sdkEvent)
    }

    // MARK: - Map Display Operations

    /// Changes the currently visible floor on the tore map
    ///
    /// - Parameter floor: New floor to switch to
    public func changeFloor(_ floor: Int) {
        compass.changeFloor(floor)
    }

    /// **Get the map view controller** - Returns the map view controller with optional workflow configuration.
    ///
    /// - Parameter workflow: Optional workflow configuration specifying the map display behavior.
    public func getMapViewController(workflow: PluginAPIs.CompassWorkflow? = nil) -> UIViewController {
        var sdkWorkflow: Workflow?
        if let w = workflow {
            sdkWorkflow = Workflow(id: w.id, type: w.type, value: w.value)
        }
        return compass.getMapViewController(workflow: sdkWorkflow)
    }

    /// **Displays pins on the map** - Show one or more aisle or campaign pins with optional zoom control.
    ///
    /// - Parameters:
    ///   - pins: Array of CompassPin objects (aisle or campaign pins) to display on the map.
    ///   - config: Optional configuration dictionary for pin display behavior.
    ///   - isZoomOutRequired: If true, automatically resets the zoom level to fit all pins.
    public func displayPin(pins: [PluginAPIs.CompassPin], config: [String: Any]?, isZoomOutRequired: Bool) {
        let sdkPins = pins.map { pin -> compass_sdk_ios.CompassPin in
            switch pin {
            case .aisle(let aislePin):
                let location = compass_sdk_ios.AisleLocation(
                    zone: aislePin.location.zone,
                    aisle: aislePin.location.aisle,
                    section: aislePin.location.section,
                    selected: aislePin.location.selected
                )
                let sdkAislePin = compass_sdk_ios.AislePin(type: aislePin.type, id: aislePin.id, location: location)
                return .aisle(sdkAislePin)
            case .campaign(let campaignPin):
                let sdkCampaignPin = compass_sdk_ios.CampaignPin(
                    type: campaignPin.type,
                    id: campaignPin.id,
                    selected: campaignPin.selected
                )
                return .campaign(sdkCampaignPin)
            }
        }
        var sdkConfig = config
        if isZoomOutRequired {
            var mutableConfig = sdkConfig ?? [:]
            mutableConfig["resetZoom"] = true
            sdkConfig = mutableConfig
        }
        compass.displayPin(pins: sdkPins, config: sdkConfig)
    }

    /// **Registers error handler for pin display** - Get notified when pin display operations fail.
    ///
    /// - Parameter handler: Callback invoked with error code and error message when pin display fails.
    public func setDisplayPinsErrorHandler(_ handler: @escaping (String, String) -> Void) {
        displayPinsErrorHandler = handler
        installEventEmitterHandlerIfNeeded()
    }

    /// **Clears the map** - Removes all pins and paths from the map view.
    ///
    /// - Parameter configuration: Optional configuration dictionary for map clearing behavior.
    public func clearMap(configuration: [String: Any]?) {
        compass.clearMap(configuration: configuration)
    }

    // MARK: - WebView Integration

    /// **Executes JavaScript in the web view** - Run custom JavaScript code directly in the Compass web view.
    ///
    /// - Parameter string: The JavaScript code to execute in the web view.
    public func evaluateJSOnWebView(_ string: String) {
        compass.evaluateJSOnWebView(string)
    }

    // MARK: - Other APIs

    /// Starts real-time positioning to track the user's location on the map.
    public func startPositioning() {
        compass.startPositioning()
    }

    /// Stops real-time positioning and location tracking.
    public func stopPositioning() {
        compass.stopPositioning()
    }

    /// Resets the position status event state.
    public func resetPositionStatusEvent() {
        compass.resetPositionStatusEvent()
    }

    /// Terminates all Compass SDK operations and cleans up resources.
    public func killSwitch() {
        compass.killSwitch()
    }

    /// Displays pins on the map using UUID identifiers.
    ///
    /// - Parameters:
    ///   - uuidList: Array of UUID strings identifying the pins to display.
    ///   - idType: The method used to identify and drop pins on the map.
    ///   - config: Optional configuration dictionary for pin display behavior.
    public func displayPin(uuidList: [String], idType: CompassPinDropMethod, config: [String: Any]?) {
        let sdkIdType = compass_sdk_ios.PinDropMethod(rawValue: idType.rawValue) ?? .generic
        compass.displayPin(uuidList: uuidList, idType: sdkIdType, config: config)
    }

    /// Displays a static path connecting multiple pins on the map.
    ///
    /// - Parameters:
    ///   - pins: Array of CompassPin objects defining the path waypoints.
    ///   - startFromNearbyEntrance: If true, the path starts from the nearest entrance.
    ///   - disableZoomGestures: If true, disables zoom gestures while the path is displayed.
    public func displayStaticPath(
        pins: [PluginAPIs.CompassPin],
        startFromNearbyEntrance: Bool,
        disableZoomGestures: Bool
    ) {
        let sdkPins = pins.map { pin -> compass_sdk_ios.CompassPin in
            switch pin {
            case .aisle(let aislePin):
                let location = compass_sdk_ios.AisleLocation(
                    zone: aislePin.location.zone,
                    aisle: aislePin.location.aisle,
                    section: aislePin.location.section,
                    selected: aislePin.location.selected
                )
                let sdkAislePin = compass_sdk_ios.AislePin(type: aislePin.type, id: aislePin.id, location: location)
                return .aisle(sdkAislePin)
            case .campaign(let campaignPin):
                let sdkCampaignPin = compass_sdk_ios.CampaignPin(
                    type: campaignPin.type,
                    id: campaignPin.id,
                    selected: campaignPin.selected
                )
                return .campaign(sdkCampaignPin)
            }
        }
        compass.displayStaticPath(
            pins: sdkPins,
            startFromNearbyEntrance: startFromNearbyEntrance,
            disableZoomGestures: disableZoomGestures
        )
    }

    /// Calculates the user's distance from specified pins.
    ///
    /// - Parameters:
    ///   - pins: Array of CompassAislePin objects to calculate distance from.
    ///   - completion: Optional callback invoked with an array of distance responses for each pin.
    public func getUserDistance(
        pins: [PluginAPIs.CompassAislePin],
        completion: PluginAPIs.CompassUserDistanceCompleteHandler?
    ) {
        let sdkPins = pins.map { aislePin -> compass_sdk_ios.AislePin in
            let location = compass_sdk_ios.AisleLocation(
                zone: aislePin.location.zone,
                aisle: aislePin.location.aisle,
                section: aislePin.location.section,
                selected: aislePin.location.selected
            )
            return compass_sdk_ios.AislePin(type: aislePin.type, id: aislePin.id, location: location)
        }

        compass.getUserDistance(pins: sdkPins, completion: { responses in
            let mapped = responses.map { response in
                PluginAPIs.CompassUserDistanceResponse(data: response.toDictionary())
            }
            completion?(mapped)
        })
    }

    /// Retrieves information about a specific aisle.
    ///
    /// - Parameter id: The identifier of the aisle to retrieve.
    public func getAisle(id: String) {
        compass.getAisle(id: id)
    }

    /// Subject indicating whether the blue dot (user location indicator) is enabled on the map.
    public var isBlueDotEnabled: Bool? {
        return compass.isBlueDotEnabled
    }

    /// The identifier of the currently active store, or nil if no store is active.
    public var currentStore: Int? {
        return compass.currentStore
    }

    /// Sets a handler to receive all events emitted by the Compass SDK.
    ///
    /// This provides a low-level event stream for all Compass events. For specific event types,
    /// consider using specialized handlers like setCompassStateHandler() or setMapInteractionsHandler().
    ///
    /// - Parameter handler: Callback invoked with CompassEventEmitter for each event, or nil to remove the handler.
    public func setEventEmitterHandler(_ handler: ((CompassEventEmitter) -> Void)?) {
        eventEmitterHandler = handler
        installEventEmitterHandlerIfNeeded()
    }
}

// MARK: - Private Helpers

extension CompassPluginAPI {
    private func createAuthParams(env: compass_sdk_ios.CompassEnvironment) -> compass_sdk_ios.AuthParameter {
        let secureKeys: SecureKeyProviding = container.get()
        let sdkAuth: AuthParameter
        let consumerId: String

        if let token = container.getIfRegistered(AuthenticationAPI.self)?.tryToGetSharedKeychainAuthToken()?.token {
            consumerId = loggedInConsumerId(for: env, secureKeys: secureKeys)

            let cid = container.getIfRegistered(AuthenticationAPI.self).value?.currentCustomer.value?.cid ?? ""
            let spid = container.getIfRegistered(AuthenticationAPI.self).value?.currentCustomer.value?.spid ?? ""
            sdkAuth = AuthParameter(
                clientSecret: token,
                tokenType: Constant.tokenType,
                accountID: cid,
                consumerID: consumerId,
                env: env,
                anonymizedUserId: cid,
                tenantId: Constant.tenantId,
                CID: cid,
                SPID: spid
            )
        } else {
            let clientSecret: String
            let vid = container.getIfRegistered(AnalyticsSessionProvider.self)?.visitorId
            consumerId = guestConsumerId(for: env, secureKeys: secureKeys)
            clientSecret = guestClientSecret(for: env, secureKeys: secureKeys)
            sdkAuth = AuthParameter(
                clientSecret: clientSecret,
                tokenType: Constant.tokenType,
                accountID: vid ?? "glass_guest_user",
                consumerID: consumerId,
                env: env,
                anonymizedUserId: vid,
                tenantId: Constant.tenantId,
                CID: nil,
                SPID: nil
            )
        }

        return sdkAuth
    }

    private func loggedInConsumerId(
        for env: compass_sdk_ios.CompassEnvironment,
        secureKeys: SecureKeyProviding
    ) -> String {
        switch env {
        case .production:
            return secureKeys.compassProdLoggedInConsumerId
        default:
            return secureKeys.compassStageLoggedInConsumerId
        }
    }

    private func guestConsumerId(
        for env: compass_sdk_ios.CompassEnvironment,
        secureKeys: SecureKeyProviding
    ) -> String {
        switch env {
        case .production:
            return secureKeys.compassProdGuestConsumerId
        default:
            return secureKeys.compassStageGuestConsumerId
        }
    }

    private func guestClientSecret(
        for env: compass_sdk_ios.CompassEnvironment,
        secureKeys: SecureKeyProviding
    ) -> String {
        switch env {
        case .production:
            return secureKeys.compassProdGuestClientSecret
        default:
            return secureKeys.compassStageGuestClientSecret
        }
    }

    private func updateAuthParamsWhenNeeded(env: compass_sdk_ios.CompassEnvironment) {
        guard let currentCustomerPublisher = container.getIfRegistered(AuthenticationAPI.self)?.currentCustomer else {
            return
        }
        updateAuthParamsCancellable?.cancel()
        updateAuthParamsCancellable = currentCustomerPublisher.sink { [weak self] _ in
            guard let self else {
                return
            }
            let newAuthParams = self.createAuthParams(env: env)
            self.compass.updateAuthParams(
                clientSecret: newAuthParams.clientSecret,
                tokenType: newAuthParams.tokenType,
                consumerID: newAuthParams.consumerID,
                accountID: newAuthParams.accountID,
                env: newAuthParams.env,
                anonymizedUserId: newAuthParams.anonymizedUserId,
                cid: newAuthParams.CID,
                spid: newAuthParams.SPID
            )
        }
    }

    private func installEventEmitterHandlerIfNeeded() {
        guard !isEventEmitterHandlerInstalled else { return }
        var statusService = compass.getStatusService()
        statusService.eventEmitterHandler = { [weak self] sdkEvent in
            guard let self else { return }

            // Map SDK event type to API event type
            let sdkEventTypeString = sdkEvent.eventType.rawValue
            let apiEventType = CompassEventType(rawValue: sdkEventTypeString) ?? .noEvent

            // Create generic event wrapper
            let genericEvent = CompassGenericEvent(
                eventType: apiEventType,
                data: sdkEvent.toDictionary()
            )

            self.eventEmitterHandler?(genericEvent)
            self.notifyMapInteractionsIfNeeded(event: genericEvent)
            self.notifyCompassStateIfNeeded(event: genericEvent)
            self.notifyDisplayPinsErrorIfNeeded(event: genericEvent)
        }
        isEventEmitterHandlerInstalled = true
    }

    private func notifyMapInteractionsIfNeeded(event: CompassEventEmitter) {
        switch event.eventType {
        case .pinClickedEventEmitter:
            guard let handler = mapInteractionOnPinClick else { return }
            let dict = event.toDictionary()
            guard let zone = dict["zone"] as? String,
                  let aisle = parseInt(dict["aisle"]),
                  let section = parseInt(dict["section"])
            else {
                return
            }
            let idValue = dict["id"]
            let id = (idValue as? String) ?? parseInt(idValue).map(String.init) ?? ""
            guard !id.isEmpty else { return }
            let pin = CompassClickedPin(id: id, zone: zone, aisle: aisle, section: section)
            handler(pin)
        case .zoomInteraction, .mapInteraction:
            guard let handler = mapInteractionOnZoomClick else { return }
            let dict = event.toDictionary()
            guard let zoomIn = dict["zoomIn"] as? Bool,
                  let zoomLevel = parseInt(dict["zoomLevel"])
            else {
                return
            }
            handler(zoomIn, zoomLevel)
        default:
            break
        }
    }

    private func notifyCompassStateIfNeeded(event: CompassEventEmitter) {
        switch event.eventType {
        case .mapStatusEventEmitter:
            guard let handler = compassStateOnMapLoaded else { return }
            let dict = event.toDictionary()
            guard let isSuccess = dict["success"] as? Bool, isSuccess else { return }
            let result = dictionaryToJSONString(dict) ?? ""
            handler(result)
        case .errorEventEmitter, .initErrorEventEmitter:
            guard let handler = compassStateOnError else { return }
            let dict = event.toDictionary()
            let errorCode = parseErrorCode(dict)
            let errorMessage = parseErrorMessage(dict)
            handler(errorCode, errorMessage)
        default:
            break
        }
    }

    private func notifyDisplayPinsErrorIfNeeded(event: CompassEventEmitter) {
        guard let handler = displayPinsErrorHandler else { return }
        guard event.eventType == .errorEventEmitter else { return }
        let dict = event.toDictionary()
        guard isDisplayPinsError(dict) else { return }
        let errorCode = parseErrorCode(dict)
        let errorMessage = parseErrorMessage(dict)
        handler(errorCode, errorMessage)
    }

    private func isDisplayPinsError(_ dict: [String: Any]) -> Bool {
        guard let compassErrorType = dict["compassErrorType"] as? String else { return false }
        return compassErrorType == "Unable to add event."
            || compassErrorType == "Map View is not present."
    }

    private func parseErrorCode(_ dict: [String: Any]) -> String {
        if let code = dict["errorCode"] as? Int {
            return String(code)
        }
        if let code = dict["errorCode"] as? String {
            return code
        }
        return "-1"
    }

    private func parseErrorMessage(_ dict: [String: Any]) -> String {
        if let message = dict["errorDescription"] as? String, !message.isEmpty {
            return message
        }
        if let message = dict["errorMessage"] as? String, !message.isEmpty {
            return message
        }
        if let message = dict["compassErrorType"] as? String, !message.isEmpty {
            return message
        }
        return ""
    }

    private func dictionaryToJSONString(_ dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func parseInt(_ value: Any?) -> Int? {
        switch value {
        case let intValue as Int:
            return intValue
        case let doubleValue as Double:
            return Int(doubleValue)
        case let stringValue as String:
            return Int(stringValue)
        default:
            return nil
        }
    }

    private func convertEnvironment(_ environment: PluginAPIs.CompassEnvironment?) -> compass_sdk_ios
        .CompassEnvironment? {
        guard let environment else { return nil }
        switch environment {
        case .staging:
            return .staging
        case .production:
            return .production
        case .perf:
            return .perf
        case .preProd:
            return .preProd
        case .stageGKE:
            return .stageGKE
        }
    }
}

private final class StatusServiceAdapter: CompassStatusService {
    private let statusService: compass_sdk_ios.StatusService

    init(statusService: compass_sdk_ios.StatusService) {
        self.statusService = statusService
    }

    func emitMapStatusEvent(isSuccess: Bool) {
        statusService.emitMapStatusEvent(isSuccess: isSuccess)
    }

    func emitLocationEvent(assetLocation: String) {
        statusService.emitLocationEvent(assetLocation: assetLocation)
    }
}

private extension compass_sdk_ios.Configuration {
    init(from clientConfiguration: CompassClientConfiguration) {
        self.init(
            country: clientConfiguration.country,
            site: clientConfiguration.site,
            userId: clientConfiguration.userId,
            siteType: SiteType(rawValue: clientConfiguration.siteType.rawValue) ?? .Store,
            mockUser: clientConfiguration.mockUser,
            anonymizedUserID: clientConfiguration.userId.hashValue.description,
            businessUnitType: BusinessUnitType(rawValue: clientConfiguration.businessUnitType.rawValue) ?? .WALMART
        )
    }
}

private extension CompassState {
    init(from state: Compass.InitializationState) {
        switch state {
        case .notInitialized:
            self = .notInitialized
        case .initializationInProgress:
            self = .initializationInProgress
        case .initializationComplete:
            self = .initializationComplete
        case .mapLoaded:
            self = .mapLoaded
        case .initializationFailed(let error):
            self = .initializationFailed(error)
        default:
            self = .notInitialized
        }
    }
}

private extension CustomMapSource {
    init(from mapSource: CompassCustomMapSource) {
        switch mapSource {
        case .urlRequest(let urlRequest):
            self = .urlRequest(urlRequest)
        case .htmlContentString(let htmlString):
            self = .htmlContentString(htmlString)
        case .htmlFilePath(let path):
            self = .htmlFilePath(path)
        }
    }
}
