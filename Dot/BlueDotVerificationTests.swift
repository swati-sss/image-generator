//
//  HomeViewModel.swift
//  Compass
//
//  Created by Platform Team on 12/10/2025.
//

import Combine
import Compass
import compass_sdk_ios
import IPSFramework
import LivingDesign3
import PluginAPIs
import PluginAPIsMocks
import SwiftUI
import UIKit
import UserNotifications
import WalmartPlatform

enum AuthTypeSelection: String, CaseIterable, Identifiable {
    case glassLoggedIn = "Glass Auth - Logged In"
    case glassGuest = "Glass Auth - Guest"
    var id: String { rawValue }
}

final class HomeViewModel: ObservableObject {
    @Published var storeIDText = String(Environment.initialStore)
    @Published var customMapStoreIDText = ""
    @Published var consoleText = ""
    @Published private var consoleScrollToken = 0
    @Published var calibrationProgress = 0.0
    @Published var positioningProgress = 0.0
    @Published var isPositionLocked = false

    @Published var shouldZoomOnPins = true
    @Published var resetZoom = false
    @Published var isConsoleHidden = true
    @Published var mapViewController: UIViewController?
    @Published var selectedAuthType: AuthTypeSelection = .glassGuest {
        didSet {
            // Clear store ID only if auth type changed
            if oldValue != selectedAuthType {
                // TODO:
                // //self.compass?.setStore(nil)
            }
        }
    }

    private let container: Container = {
        let container = Container(parent: .mock)
        container.register(SecureKeyProviding.self) { MockSecureKeys() }
        container.registerProvidingChild(CompassPluginAPI.self) { CompassPluginAPI(container: $0) }
        return container
    }()

    private lazy var compassAPI: CompassPluginAPI = container.get()
    private lazy var secureKeys: SecureKeyProviding = container.get()

    // To use the clientSec inside another plugin
    // let secureKeys: SecureKeyProviding = container.get()
    // let compassSecret = secureKeys.compassStageGuestClientSecret

    ///    private var compass: Compass?
    /// TODO: This property is used for same-store check which should be moved to SDK
    /// Once SDK handles duplicate initialization, this may not be needed in the app layer
    var currentStore: Int?
    var cancellable = Set<AnyCancellable>()
    let mapRootViewController = UIViewController()

    var pinDropEventEmitterHandler: ((CompassEventEmitter) -> Void)?
    var pinClickedEventEmitterHandler: ((CompassEventEmitter) -> Void)?
    var aislePinDropEventEmitterHandler: ((CompassEventEmitter) -> Void)?
    var bootstrapEventEmitterHandler: ((CompassEventEmitter) -> Void)?
    var updateEventListEmitterHandler: ((CompassEventEmitter) -> Void)?
    var errorEventEmitterHandler: ((CompassEventEmitter) -> Void)?
    let didMapLoad = PassthroughSubject<Bool, Never>()

    typealias AisleTuple = (zone: String, aisle: String, section: String, selected: Bool)

    private var currentGeoFenceState: String? = "undefined"

    var enableManualPinDrop = true
    var displayPinConfig: compass_sdk_ios.DisplayPinConfig {
        compass_sdk_ios.DisplayPinConfig(
            enableManualPinDrop: enableManualPinDrop,
            resetZoom: resetZoom,
            shouldZoomOnPins: shouldZoomOnPins
        )
    }

    private let localMapDefaultsKey = "CompassLocalMapHTMLPath"
    @Published private(set) var localMapURL: URL?

    init() {
//        loadLocalMapOverride()
    }

    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "hh:mm:ss.SSSS"
        return df
    }()

    func consoleLog(_ text: String) {
        let ts = Self.timestampFormatter.string(from: Date())
        let chunk = "\n\n\(ts)\n\(text)"
        DispatchQueue.main.async {
            self.consoleText += chunk
            self.consoleScrollToken &+= 1
        }
    }

    var scrollToken: Int { consoleScrollToken }

    func reset() {
        cancellable.removeAll()
    }

    // MARK: - Setup Handlers Example

    func setupCompassHandlers() {
        // 1. Set the event emitter handler (closure for all events)
        compassAPI.setEventEmitterHandler { [weak self] event in
            guard let self else { return }
            consoleLog("EVENT: \(event.eventType.rawValue)")
        }

        // 4. Set display pins error handler (pin display errors)
        compassAPI.setDisplayPinsErrorHandler { [weak self] code, msg in
            self?.consoleLog("⚠️ Pin Error [\(code)]: \(msg)")
        }
    }

    func sendGeoFenceEnteredNotification() {
        NotificationManager.shared.post(
            title: "Geofence",
            body: "You entered the store geofence",
            id: "geofence-entered"
        )
    }

    func sendGeoFenceExitedNotification() {
        NotificationManager.shared.post(title: "Geofence", body: "You exited the store geofence", id: "geofence-exited")
    }

    func sendPositionDropNotification() {
        NotificationManager.shared.post(
            title: "Position Lost",
            body: "Indoor positioning has lost track of your location",
            id: "position-dropped"
        )
    }

    func copyConsoleTextToClipboard() {
        UIPasteboard.general.string = consoleText
    }

    func clearConsole() {
        consoleText = ""
    }

    func toggleConsoleVisibility() {
        isConsoleHidden.toggle()
    }

    func clearMap() {
        compassAPI.clearMap(configuration: compass_sdk_ios.MapConfig(resetZoom: resetZoom).hashMap)
    }

    func stopPositioning() {
        compassAPI.stopPositioning()
    }

    func getLocation(assetId: String) {
        compassAPI.getAisle(id: assetId)
    }

    func killSwitch() {
        removeCompassAndDestroyRoot()
    }

    func removeCompassAndDestroyRoot() {
        compassAPI.killSwitch()
//        mapRootViewController.view.subviews.forEach { $0.removeFromSuperview() }
//        compass = nil
    }

    private func normalizeStoreInput() {
        let trimmedStore = storeIDText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedStore.isEmpty || Int(trimmedStore) == nil {
            storeIDText = String(Environment.initialStore)
        } else if trimmedStore != storeIDText {
            storeIDText = trimmedStore
        }
    }

    private func restartCompassIfNeeded() {
//        guard compass != nil else { return }
        removeCompassAndDestroyRoot()
        currentStore = nil
        initialize()
    }

    // private func loadLocalMapOverride() {
    //    let defaults = UserDefaults.standard
    //    guard let storedPath = defaults.string(forKey: localMapDefaultsKey) else {
    //        localMapURL = nil
    //        Compass.setLocalMapFileURL(nil)
    //        return
    //    }
    //
    //    let url = URL(fileURLWithPath: storedPath)
    //    if FileManager.default.fileExists(atPath: url.path) {
    //        localMapURL = url
    //        Compass.setLocalMapFileURL(url)
    //    } else {
    //        defaults.removeObject(forKey: localMapDefaultsKey)
    //        localMapURL = nil
    //        Compass.setLocalMapFileURL(nil)
    //    }
    // }

    // func setLocalMapOverride(_ url: URL?) {
    //    if localMapURL == url {
    //        return
    //    }
    //
    //    let defaults = UserDefaults.standard
    //    if let url {
    //        defaults.set(url.path, forKey: localMapDefaultsKey)
    //    } else {
    //        defaults.removeObject(forKey: localMapDefaultsKey)
    //    }
    //
    //    localMapURL = url
    //    Compass.setLocalMapFileURL(url)
    //    compass?.setLocalMapFileURL(url)
    //
    //    if let url {
    //        consoleLog("Local map override loaded: \(url.lastPathComponent)")
    //    } else {
    //        consoleLog("Local map override cleared. Reverting to backend map.")
    //    }
    //
    //    normalizeStoreInput()
    //    restartCompassIfNeeded()
    // }

    var localMapFileName: String? {
        localMapURL?.lastPathComponent
    }

    func applyEnvironmentChangesAndReinitializeIfNeeded() {
        normalizeStoreInput()
        if Environment.mockUser {
            IPSPositioning.testLockThreshold = 0
        } else {
            IPSPositioning.testLockThreshold = 1
        }
        restartCompassIfNeeded()
    }

    func updateEvent() {
        Log.debug("Compass: updateEvent called.")
        compassAPI.state
            .first(where: { $0 == .initializationComplete })
            .sink { [weak self] _ in
                let uuid =
                    self?.storeIDText == DebugData.StoreID.oriient ?
                    DebugData.asset2280List.shuffled() : DebugData.asset3594List.shuffled()

                guard let assetId = uuid.first
                else {
                    Log.debug("Compass: isInitialize is not set.")
                    return
                }

                let compassEvent = PluginAPIs.CompassEvent(
                    eventType: "asset_scan",
                    eventValue: assetId,
                    eventMetadata: [:]
                )
                self?.compassAPI.updateEvent(compassEvent: compassEvent)
            }
            .store(in: &cancellable)

        var isCancelled = false
        var updateStatus = true

        // Observe error and progress update
        bootstrapEventEmitterHandler = { eventEmitter in
            var dict = eventEmitter.toDictionary()
            Log.debug("The value of bootstrapEventEmitterHandler dict is:\(dict)")
            dict["eventType"] = nil

            DispatchQueue.main.async { [self] in
                consoleLog("BOOTSTRAP EVENT:\n\(dict.toJSONString() ?? "")")
            }

            isCancelled = true

            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("Compass updateEvent success")
        }

        if !isCancelled {
            errorEventEmitterHandler = { errorEventEmitter in
                let dict = errorEventEmitter.toDictionary()
                Log.debug("The value of errorEventEmitterHandler dict is:\(dict)")

                var event = [String: Any]()
                if let code = dict["errorCode"] as? Int {
                    event["code"] = code
                }
                if let errorType = dict["compassErrorType"] as? String {
                    event["errortype"] = errorType
                }
                if let message = dict["errorDescription"] as? String {
                    event["message"] = message
                }

                DispatchQueue.main.async { [self] in
                    consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
                }

                Log.debug(" sendEvent errorEventEmitter body: \(event)")
                guard updateStatus else {
                    return
                }

                updateStatus = false
                Log.debug("-1 Compass updateEvent failed")
            }
        }
    }

    func updateEventList() {
        Log.debug("Compass: updateEvent List called.")

        var isCancelled = false
        var updateStatus = true

        updateEventListEmitterHandler = { eventEmitter in
            var dict = eventEmitter.toDictionary()
            Log.debug("The value of updateEventListEmitterHandler dict is:\(dict)")
            dict["eventType"] = nil

            DispatchQueue.main.async { [self] in
                consoleLog("UPDATE EVENT LIST:\n\(dict.toJSONString() ?? "")")
            }

            isCancelled = true

            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("Compass updateEvent list success")
        }
        if !isCancelled {
            errorEventEmitterHandler = { errorEventEmitter in
                let dict = errorEventEmitter.toDictionary()
                Log.debug("The value of errorEventEmitterHandler dict is:\(dict)")

                var event = [String: Any]()
                if let code = dict["errorCode"] as? Int {
                    event["code"] = code
                }
                if let errorType = dict["compassErrorType"] as? String {
                    event["errortype"] = errorType
                }
                if let message = dict["errorDescription"] as? String {
                    event["message"] = message
                }

                DispatchQueue.main.async { [self] in
                    consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
                }

                Log.debug(" sendEvent errorEventEmitter body: \(event)")
                guard updateStatus else {
                    return
                }

                updateStatus = false
                Log.debug("-1 Compass updateEvent failed")
            }
        }

        compassAPI.state
            .first(where: { $0 == .initializationComplete })
            .sink { [weak self] _ in
                self?.compassAPI.updateEventList(
                    namespace: "MODFLEX",
                    eventType: "SCAN_FEATURE_LOCATION",
                    eventValue: "BK4-12",
                    metaData: [
                        "keyA": "va",
                        "keyB": "vb",
                        "keyC": "vc",
                        "keyD": "vd",
                        "keyE": "ve",
                        "keyF": "vf"
                    ]
                )
            }
            .store(in: &cancellable)
    }

    func initialize(autoZoom: Bool = true, customMapRequest: URLRequest? = nil) {
        normalizeStoreInput()
        reset()
        // TODO: Setting currentStore from SDK for same-store check (commented out below)
        // This line may not be needed once SDK handles duplicate initialization internally
        currentStore = compassAPI.currentStore

        guard let site = Int(storeIDText) else {
            Log.debug("Compass Initialization failed: invalid store ID")
            return
        }

        // TODO: Move this same-store check into the SDK itself
        // The SDK should internally handle the case where initialize is called
        // with the same store ID and either skip re-initialization or call
        // resetPositionStatusEvent as needed. For now, commenting this out to
        // allow re-initialization when auth type changes.
        //
        // guard currentStore != site else {
        //     compassAPI.resetPositionStatusEvent()
        //     Log.debug("Already on store \(site), skipping initialization; resetting position status")
        //     return
        // }

//        self.compass = Compass()

//        guard let compass else {
//            Log.debug("Compass Initialization failed: counld not create Compass instance")
//            return
//        }

        let mapViewController = compassAPI.getMapViewController()
        self.mapViewController = mapViewController

        switch selectedAuthType {
        case .glassLoggedIn:
            Environment.tokenType = .glass
            Environment.glassAuthType = .loggedIn
            consoleLog("Using Glass Auth - Logged-In User")
        case .glassGuest:
            Environment.tokenType = .glass
            Environment.glassAuthType = .guest
            consoleLog("Using Glass Auth - Guest User")
        }

//        let authParameter = Environment.authParmeter
        let configuration = Environment.getConfiguration(for: site)
        var updateStatus = true

        cancellable.removeAll()
        consoleText = ""

        // Setup all handlers before initialization
        setupCompassHandlers()

        var customRequest: CompassCustomMapSource?
        if let customMapRequest {
            customRequest = CompassCustomMapSource.urlRequest(customMapRequest)
        }

        compassAPI.state
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    self?.consoleLog("Compass Initialization Failed: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] state in
                switch state {
                case .initializationComplete:
                    self?.consoleLog("Compass Initialization Succeeded")
                    self?.consoleLog("Compass: isBlueDotEnabled: \(self?.compassAPI.isBlueDotEnabled ?? false)")
                    self?.currentStore = site
                    guard updateStatus else {
                        return
                    }
                    updateStatus = false
                case .mapLoaded:
                    self?.consoleLog("Map Loaded")
                case .initializationFailed(let error):
                    Log.debug("Compass: Compass Initialization Failed, error: \(error)")
                    DispatchQueue.main.async {
                        self?.consoleLog("Compass Initialization Failed")
                    }
                    return
                default:
                    break
                }
            })
            .store(in: &cancellable)

        let errorEventEmitterCompletionHandler: ([String: Any]) -> Void = { dict in
            var event = [String: Any]()
            if let code = dict["errorCode"] as? Int {
                event["code"] = code
            }
            if let errortype = dict["compassErrorType"] as? String {
                event["errortype"] = errortype
            }
            if let message = dict["errorDescription"] as? String {
                event["message"] = message
            }
            DispatchQueue.main.async { [self] in
                consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
            }
            Log.debug("The value of errorEventEmitter dict is:\(event)")
            guard updateStatus else { return }
            updateStatus = false
            Log.debug("-1 Compass Initialization failed")
        }

        waitForEventEmitterCompletionHandlerResponse(with: errorEventEmitterCompletionHandler)

        compassAPI.selectedFloorPublisher
            .sink { [weak self] floor in
                self?.consoleLog("Floor cahnged to: \(floor)")
            }
            .store(in: &cancellable)

        compassAPI.webViewMessagePublisher
            .sink { message in
                self.consoleLog("WebView Response: \(message)")
            }
            .store(in: &cancellable)

        compassAPI.poiClickedPublisher
            .sink { poi in
                self.consoleLog("POI Clicked info: \(poi)")
            }
            .store(in: &cancellable)

        compassAPI.initialize(configuration: configuration, customMapSource: customRequest)
    }

    func updateGlassAuthParams() {
        // Handle Glass auth parameter update without reinitializing
//        guard compass != nil else {
//            Log.debug("Compass is not initialized. Cannot update auth params.")
//            consoleLog("Error: Compass is not initialized")
//            return
//        }

        Environment.tokenType = .glass
        Environment.glassAuthType = .loggedIn
//        let authParam = Environment.authParmeter

        // Update auth without reinitializing the map
//        compassAPI.updateAuthParams(authParameter: authParam)
        consoleLog("Called updateAuthParams with Logged-In Glass Auth")
    }

    func updateAuthParamsWithGlassGuest() {
//        guard compass != nil else {
//            Log.debug("Compass is not initialized. Cannot update auth params.")
//            consoleLog("Error: Compass is not initialized")
//            return
//        }

        Environment.tokenType = .glass
        Environment.glassAuthType = .guest
//        let authParam = Environment.authParmeter

//        compassAPI.updateAuthParams(authParameter: authParam)
        consoleLog("Called updateAuthParams with Guest Glass Auth")
    }

    func waitForEventEmitterCompletionHandlerResponse(
        with errorEventEmitterCompletionHandler: @escaping ([String: Any]) -> Void
    ) {
        compassAPI.setEventEmitterHandler { [weak self] eventEmitter in
            guard let self else { return }
            let dict = eventEmitter.toDictionary()
            switch eventEmitter.eventType {
            case .showMapEventEmitter:
                var hashMap = dict
                hashMap["eventType"] = nil
                DispatchQueue.main.async {
                    self.consoleLog("SHOW MAP EVENT:\n\(hashMap.toJSONString() ?? "")")
                }
                Log.debug("The value of mapButtonEventEmitter dict is:\(hashMap)")
            case .mapStatusEventEmitter:
                var hashMap = dict
                hashMap["eventType"] = nil
                DispatchQueue.main.async {
                    self.consoleLog("MAP STATUS EVENT:\n\(hashMap.toJSONString() ?? "")")
                }
                Log.debug("The value of mapStatusEventEmitter dict is:\(hashMap)")
            case .bootstrapEventEmitter:
                bootstrapEventEmitterHandler?(eventEmitter)
            case .updateEventListEventEmitter:
                updateEventListEmitterHandler?(eventEmitter)
            case .pinListEventEmitter:
                pinDropEventEmitterHandler?(eventEmitter)
            case .pinClickedEventEmitter:
                pinClickedEventEmitterHandler?(eventEmitter)
            case .aislesPinListEventEmitter:
                aislePinDropEventEmitterHandler?(eventEmitter)
            case .errorEventEmitter:
                errorEventEmitterHandler?(eventEmitter)
            case .positioningStateEventEmitter:
                DispatchQueue.main.async {
                    let calibration = dict["calibrationProgress"] as? Double
                        ?? (dict["calibrationProgress"] as? Int).map(Double.init)
                        ?? 0.0
                    let positioning = dict["positioningProgress"] as? Double
                        ?? (dict["positioningProgress"] as? Int).map(Double.init)
                        ?? 0.0
                    let isLocked = dict["isPositionLocked"] as? Bool ?? false

                    self.calibrationProgress = calibration / 100.0
                    self.positioningProgress = positioning / 100.0

                    if isLocked, !self.isPositionLocked {
                        self.isPositionLocked = true
                        self.consoleLog("**** POSITION LOCKED ****")
                    }
                    if !isLocked && self.isPositionLocked {
                        self.isPositionLocked = false
                        self.consoleLog("**** POSITION DROPPED ****")
                        self.sendPositionDropNotification()
                    }
                }

            case .positionEventEmitter:
                if let positionType = dict["positionType"] as? String {
                    var event = [String: Any]()
                    event["EventType"] = positionType
                    event["EventCode"] = dict["positionCode"]
                    DispatchQueue.main.async {
                        self.consoleLog("POSITIONING EVENT:\n\(event.toJSONString() ?? "")")
                    }
                    Log.debug("The value of positionEventEmitter dict is:\(event)")
                }

                if let position = dict["positionCode"] as? Int, position == 0 {
                    updateEvent()
                }
            case .initErrorEventEmitter:
                errorEventEmitterCompletionHandler(dict)
            case .geofenceStateEventEmitter:
                let newState = dict["state"] as? String
                    ?? dict["geofenceState"] as? String
                    ?? "undefined"
                let previousState = currentGeoFenceState ?? "undefined"

                guard previousState != newState else {
                    Log.debug("Geofence state unchanged: \(newState)")
                    return
                }

                switch newState {
                case "inside":
                    if previousState == "outside" || previousState == "undefined" {
                        sendGeoFenceEnteredNotification()
                        consoleLog("**** ENTERED GEOFENCE from \(previousState) ****")
                    }
                case "outside":
                    if previousState == "inside" || previousState == "undefined" {
                        sendGeoFenceExitedNotification()
                        consoleLog("**** EXITED GEOFENCE ****")
                    }
                default:
                    consoleLog("**** UNKNOWN state: \(newState) ****")
                }
                currentGeoFenceState = newState
            default:
                break
            }
        }
    }

    func evaluateJsExample() {
        guard mapViewController != nil else {
            consoleLog("evaluateJsExample: Compass is not initialized")
            return
        }

        let payload = """
        {\"type\":\"RENDER_PINS_REQUESTED\",\"payload\":{\"pinGroupingEnabled\":true,\
        "pins\":[{\"aisle\":1,\"selected\":true,\"type\":\"aisle-section\",\"shouldFetchData\":false, \
        \"zone\":\"A\",\"grouped\":true,\"section\":1,\"groupedPins\":[],\"checked\":false}]}}
        """
        let escaped = payload.replacingOccurrences(of: "'", with: "\\'")
        compassAPI.evaluateJSOnWebView("sendMessage('\(escaped)')")
    }

    func displayAssetPin(id: String) {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        setAndGetAssetsEventStatus()
        compassAPI.displayPin(uuidList: [id], idType: .assets, config: displayPinConfig.hashMap)
    }

    func displayGenericPin(encodedId: String) {
        guard !encodedId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        setAndGetAssetsEventStatus()
        compassAPI.displayPin(uuidList: [encodedId], idType: .generic, config: nil)
    }

    func displayPinsV2(pins: [AisleTuple], isStaticPathVisible: Bool = false) {
        var updateStatus = true

        aislePinDropEventEmitterHandler = { pinDropEventEmitter in
            var dict = pinDropEventEmitter.toDictionary()
            dict["eventType"] = nil

            Log.debug("The value of aislePinDropEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Display Pins Payload for Aisle: \(output)")
                DispatchQueue.main.async { [self] in
                    consoleLog("PIN DROP V2 EVENT:\n\(output)")
                }
            }

            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("displaypin success")
        }

        pinClickedEventEmitterHandler = { pinClickedEventEmitter in
            var dict = pinClickedEventEmitter.toDictionary()
            dict["eventType"] = nil
            Log.debug("The value of pinClickedEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Pin Clicked: \(output)")
                DispatchQueue.main.async { [self] in
                    consoleLog("PIN CLICKED EVENT:\n\(output)")
                }
            }
        }

        var isZoomOutRequired = true
        let aislePins: [PluginAPIs.CompassAislePin] = pins.map { tuple in
            if !tuple.zone.isEmpty && !tuple.aisle.isEmpty && !tuple.section.isEmpty {
                isZoomOutRequired = false
            }
            return PluginAPIs.CompassAislePin(
                type: "user",
                id: UUID().uuidString,
                location: PluginAPIs.CompassAisleLocation(
                    zone: tuple.zone,
                    aisle: tuple.aisle,
                    section: tuple.section,
                    selected: tuple.selected
                )
            )
        }

        if isStaticPathVisible {
            let compassPins = aislePins.map { PluginAPIs.CompassPin.aisle($0) }
            compassAPI.displayStaticPath(
                pins: compassPins,
                startFromNearbyEntrance: true,
                disableZoomGestures: false
            )
        } else {
            var compassPins = aislePins.map { PluginAPIs.CompassPin.aisle($0) }
            // Append a sample campaign pin
            compassPins.append(.campaign(PluginAPIs.CompassCampaignPin(type: "campaign", id: 2)))
            compassAPI.displayPin(
                pins: compassPins,
                config: displayPinConfig.hashMap,
                isZoomOutRequired: isZoomOutRequired
            )
        }
    }

    func displayCampaignPinSample() {
        let compassPins: [PluginAPIs.CompassPin] = [
            .campaign(PluginAPIs.CompassCampaignPin(type: "campaign", id: 2, selected: false))
        ]
        compassAPI.displayPin(pins: compassPins, config: displayPinConfig.hashMap, isZoomOutRequired: false)
    }

    func getUserDistance(zone: String, aisle: String, section: String) {
        let trimmedZone = zone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAisle = aisle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSection = section.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedZone.isEmpty, !trimmedAisle.isEmpty, !trimmedSection.isEmpty else {
            consoleLog("Please provide zone, aisle, and section to calculate distance.")
            return
        }

        let location = PluginAPIs.CompassAisleLocation(
            zone: trimmedZone,
            aisle: trimmedAisle,
            section: trimmedSection,
            selected: true
        )
        let pin = PluginAPIs.CompassAislePin(
            type: "user_distance",
            id: UUID().uuidString,
            location: location
        )

        consoleLog("Requesting distance to \(trimmedZone)-\(trimmedAisle)-\(trimmedSection)")
        requestUserDistance(for: [pin])
    }

    func testGetUserDistanceWithHardcodedPin() {
        let pin = PluginAPIs.CompassAislePin(
            type: "item",
            id: "123",
            location: PluginAPIs.CompassAisleLocation(zone: "A", aisle: "1", section: "1", selected: true)
        )
        consoleLog("Called getUserDistance with hardcoded pin: \(pin)")
        requestUserDistance(for: [pin])
    }

    private func requestUserDistance(for pins: [PluginAPIs.CompassAislePin]) {
        guard !pins.isEmpty else { return }

        var updateStatus = true

        aislePinDropEventEmitterHandler = { pinDropEventEmitter in
            var dict = pinDropEventEmitter.toDictionary()
            dict["eventType"] = nil

            Log.debug("The value of aislePinDropEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Display Pins Payload for Aisle: \(output)")
                DispatchQueue.main.async { [self] in
                    consoleLog("PIN DROP V2 EVENT:\n\(output)")
                }
            }

            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("displaypin success")
        }

        pinClickedEventEmitterHandler = { pinClickedEventEmitter in
            var dict = pinClickedEventEmitter.toDictionary()
            dict["eventType"] = nil
            Log.debug("The value of pinClickedEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Pin Clicked: \(output)")
                DispatchQueue.main.async { [self] in
                    consoleLog("PIN CLICKED EVENT:\n\(output)")
                }
            }
        }

        compassAPI.getUserDistance(pins: pins) { responses in
            responses.forEach { response in
                let dict = response.data
                if let output = dict.toJSONString() {
                    DispatchQueue.main.async { [self] in
                        consoleLog("USER DISTANCE RESPONSE:\n\(output)")
                    }
                }
            }
        }
    }

    func setAndGetAssetsEventStatus() {
        var updateStatus = true

        pinDropEventEmitterHandler = { pinDropEventEmitter in
            var dict = pinDropEventEmitter.toDictionary()
            dict["eventType"] = nil
            Log.debug("The value of pinDropEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Display Pins Payload for Asset or Generic: \(output)")
                DispatchQueue.main.async { [self] in
                    consoleLog("PIN DROP EVENT:\n\(output)")
                }
            }

            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("displaypin success")
        }

        errorEventEmitterHandler = { errorEventEmitter in
            let dict = errorEventEmitter.toDictionary()
            Log.debug("The value of errorEventEmitterHandler dict is:\(dict)")

            var event = [String: Any]()
            if let code = dict["errorCode"] as? Int {
                event["code"] = code
            }
            if let errortype = dict["compassErrorType"] as? String {
                event["errortype"] = errortype
            }
            if let message = dict["errorDescription"] as? String {
                event["message"] = message
            }
            Log.debug("SendEvent wih errorEventEmitter and body \(event)")
            DispatchQueue.main.async { [self] in
                consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
            }
            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("-1 Compass displayPins failed")
        }
    }
}
