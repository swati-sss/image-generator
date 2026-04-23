//
//  CompassBridge.swift
//  compass-sample-app
//
//  Created by p0a0595 on 9/11/25.
//

import SwiftUI
import Combine
import compass_sdk_ios
import LivingDesign
import UserNotifications
import IPSFramework

enum AuthTypeSelection: String, CaseIterable, Identifiable {
    case standardIAM = "Standard Auth - IAM"
    case standardUser = "Standard Auth - User"
    case standardPingfed = "Standard Auth - Pingfed"
    case glassLoggedIn = "Glass Auth - Logged In"
    case glassGuest = "Glass Auth - Guest"

    var id: String { rawValue }
}

final class HomeViewModel: ObservableObject {
    
    @Published var storeIDText: String = String(Environment.initialStore)
    @Published var customMapStoreIDText: String = ""
    @Published var consoleText: String = ""
    @Published private var consoleScrollToken: Int = 0
    @Published var calibrationProgress: Double = 0.0
    @Published var positioningProgress: Double = 0.0
    @Published var isPositionLocked: Bool = false
    
    @Published var shouldZoomOnPins: Bool = true
    @Published var resetZoom: Bool = false
    @Published var userDistanceResult: String = ""
    @Published var shouldShowDistanceAlert: Bool = false
    @Published var isConsoleHidden: Bool = true
    @Published var shouldReloadMap: Bool = false
    @Published var mapViewController: UIViewController?
    @Published var selectedAuthType: AuthTypeSelection = .standardUser {
        didSet {
            // Clear store ID only if auth type changed
            if oldValue != selectedAuthType {
//                compass?.currentStore = nil
                self.compass?.setStore(nil)
            }
        }
    }

    var compass: Compass?
    var currentStore: Int?
    var cancellables = Set<AnyCancellable>()
    let mapRootViewController = LDRootViewController()

    var pinDropEventEmitterHandler: ((PinDropEventEmitter) -> Void)?
    var pinClickedEventEmitterHandler: ((PinClickedEventEmitter) -> Void)?
    var aislePinDropEventEmitterHandler: ((PinDropEventEmitter) -> Void)?
    var bootstrapEventEmitterHandler: ((EventEmitterDescription) -> Void)?
    var updateEventListEmitterHandler: ((EventEmitterDescription) -> Void)?
    var errorEventEmitterHandler: ((ErrorEventEmitter) -> Void)?
    
    typealias AisleTuple = (zone: String, aisle: String, section: String, selected: Bool)
    
    private var currentGeoFenceState: String? = "undefined"
    
    var enableManualPinDrop: Bool = true
    var displayPinConfig: DisplayPinConfig {
        DisplayPinConfig(enableManualPinDrop: enableManualPinDrop, resetZoom: resetZoom, shouldZoomOnPins: shouldZoomOnPins)
    }
    
    private let localMapDefaultsKey = "CompassLocalMapHTMLPath"
    @Published private(set) var localMapURL: URL?

    init() {
        loadLocalMapOverride()
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
        cancellables.removeAll()
    }
    
    func sendGeoFenceEnteredNotification() {
        NotificationManager.shared.post(title: "Geofence", body: "You entered the store geofence", id: "geofence-entered")
    }
    
    func sendGeoFenceExitedNotification() {
        NotificationManager.shared.post(title: "Geofence", body: "You exited the store geofence", id: "geofence-exited")
    }
    
    func sendPositionDropNotification() {
        NotificationManager.shared.post(title: "Position Lost", body: "Indoor positioning has lost track of your location", id: "position-dropped")
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
        compass?.clearMap(configuration: MapConfig(resetZoom: resetZoom).hashMap)
    }
    
    func stopPositioning() {
        compass?.killSwitch()
    }

    func getLocation(assetId: String) {
        compass?.getAisle(id: assetId)
    }
    
    func killSwitch() {
        removeCompassAndDestroyRoot()
    }
    
    func removeCompassAndDestroyRoot() {
        compass?.killSwitch()
        compass = nil
//        if let compass = compass {
//            compass.willMove(toParent: nil)
//            compass.view.removeFromSuperview()
//            compass.removeFromParent()
//        }

        mapRootViewController.view.subviews.forEach {$0.removeFromSuperview()}

        compass = nil
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
        guard compass != nil else { return }
        removeCompassAndDestroyRoot()
        currentStore = nil
        initialize(false)
    }
    
    private func loadLocalMapOverride() {
        let defaults = UserDefaults.standard
        guard let storedPath = defaults.string(forKey: localMapDefaultsKey) else {
            localMapURL = nil
            Compass.setLocalMapFileURL(nil)
            return
        }

        let url = URL(fileURLWithPath: storedPath)
        if FileManager.default.fileExists(atPath: url.path) {
            localMapURL = url
            Compass.setLocalMapFileURL(url)
        } else {
            defaults.removeObject(forKey: localMapDefaultsKey)
            localMapURL = nil
            Compass.setLocalMapFileURL(nil)
        }
    }
    
    func setLocalMapOverride(_ url: URL?) {
        if localMapURL == url {
            return
        }

        let defaults = UserDefaults.standard
        if let url {
            defaults.set(url.path, forKey: localMapDefaultsKey)
        } else {
            defaults.removeObject(forKey: localMapDefaultsKey)
        }

        localMapURL = url
        Compass.setLocalMapFileURL(url)
        compass?.setLocalMapFileURL(url)

        if let url {
            consoleLog("Local map override loaded: \(url.lastPathComponent)")
        } else {
            consoleLog("Local map override cleared. Reverting to backend map.")
        }

        normalizeStoreInput()
        restartCompassIfNeeded()
    }
    
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
        compass?.state
            .map { $0 == .initializationComplete }
            .sink { isInitialized in
                let uuid =
                self.storeIDText == DebugData.StoreID.oriient ?
                DebugData.asset2280List.shuffled() : DebugData.asset3594List.shuffled()

                guard isInitialized, let assetId = uuid.first else {
                    Log.debug("Compass: isInitialize is not set.")
                    return
                }

                let compassEvent = CompassEvent(eventType: "asset_scan",
                                                eventValue: assetId,
                                                eventMetadata: [:])
                self.compass?.updateEvent(compassEvent: compassEvent)
            }
            .store(in: &cancellables)

        var isCancelled = false
        var updateStatus = true

        //Observe error and progress update
        bootstrapEventEmitterHandler = { eventEmitterDescription in
            var dict = eventEmitterDescription.toDictionary()
            Log.debug("The value of bootstrapEventEmitterHandler dict is:\(dict)")
            dict["eventType"] = nil

            DispatchQueue.main.async {
                self.consoleLog("BOOTSTRAP EVENT:\n\(dict.toJSONString() ?? "")")
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

                var event = [String : Any]()
                if let code = dict["errorCode"] as? Int {
                    event["code"] = code
                }
                if let errorType = dict["compassErrorType"] as? String {
                    event["errortype"] = errorType
                }
                if let message = dict["errorDescription"] as? String {
                    event["message"] = message
                }

                DispatchQueue.main.async {
                    self.consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
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

        updateEventListEmitterHandler = { eventEmitterDescription in
            var dict = eventEmitterDescription.toDictionary()
            Log.debug("The value of updateEventListEmitterHandler dict is:\(dict)")
            dict["eventType"] = nil

            DispatchQueue.main.async {
                self.consoleLog("UPDATE EVENT LIST:\n\(dict.toJSONString() ?? "")")
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

                var event = [String : Any]()
                if let code = dict["errorCode"] as? Int {
                    event["code"] = code
                }
                if let errorType = dict["compassErrorType"] as? String {
                    event["errortype"] = errorType
                }
                if let message = dict["errorDescription"] as? String {
                    event["message"] = message
                }

                DispatchQueue.main.async {
                    self.consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
                }

                Log.debug(" sendEvent errorEventEmitter body: \(event)")
                guard updateStatus else {
                    return
                }

                updateStatus = false
                Log.debug("-1 Compass updateEvent failed")
            }
        }

        compass?.state
            .map { $0 == .initializationComplete }
            .sink { isInitialize in
                let uuid =
                self.storeIDText == DebugData.StoreID.oriient ?
                DebugData.asset2280List.shuffled() : DebugData.asset3594List.shuffled()

                guard isInitialize, let assetId = uuid.first else {
                    Log.debug("Compass: isInitialize is not set.")
                    return
                }

                self.compass?.updateEventList(
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
            .store(in: &cancellables)

    }
    
    
    func initialize(_ disableAutoZoom: Bool) {
        normalizeStoreInput()
        reset()
        self.currentStore = compass?.currentStore

        guard let site = Int(storeIDText) else {
            Log.debug("Compass Initialization failed: invalid store ID")
            return
        }

        guard self.currentStore != site else {
            self.compass?.resetPositionStatusEvent()
            Log.debug("Already on store \(site), skipping initialization; resetting position status")
            return
        }

        self.compass = Compass()
        guard let compass = self.compass else {
            Log.debug("Compass Initialization failed: counld not create Compass instance")
            return
        }

        // Register this view model as the webview message delegate via the
        // public Compass API so HomeView can provide the delegate to the SDK.
        compass.setWebViewMessageDelegate(self)

        let authParameter = Environment.authParmeter
        let configuration = Environment.getConfiguration(for: site)
        var updateStatus = true

        cancellables.removeAll()
        consoleText  = ""

        let customMapURL: URL? = !customMapStoreIDText.isEmpty
            ? URL(string: "https://developer.api.walmart.com/api-proxy/service/Store-Services/Instore-Maps/v1/store/\(customMapStoreIDText)/map")
            : nil

        var customMapRequest: URLRequest? = nil
        if let url = customMapURL {
            customMapRequest = URLRequest(url: url)
        }

        // Create auth parameter based on selection
        switch selectedAuthType {
        case .standardIAM:
            compass.setEnvironment(Environment.backendEnv)
            Environment.tokenType = .IAM
            consoleLog("Using Standard Auth - IAM Token")
        case .standardUser:
            compass.setEnvironment(Environment.backendEnv)
            Environment.tokenType = .User
            consoleLog("Using Standard Auth - User Token")
        case .standardPingfed:
            compass.setEnvironment(Environment.backendEnv)
            Environment.tokenType = .Pingfed
            consoleLog("Using Standard Auth - Pingfed Token")
        case .glassLoggedIn:
            Environment.tokenType = .glass
            Environment.glassAuthType = .loggedIn
            consoleLog("Using Glass Auth - Logged-In User")
        case .glassGuest:
            Environment.tokenType = .glass
            Environment.glassAuthType = .guest
            consoleLog("Using Glass Auth - Guest User")
        }

        let authParam = Environment.authParmeter

        Just(compass.initialize(
            authParameter: authParam,
            configuration: configuration,
            customMapRequest: customMapRequest,
            completion: { [weak self] mapViewController in
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    self.mapViewController = mapViewController
                }
            },
            onError: { [weak self] error in
                Log.debug(error.localizedDescription)
                self?.consoleLog("Error: \(error.localizedDescription)")
            }
        ))
        .eraseToAnyPublisher()
        .flatMap { _ in
            Publishers
                .CombineLatest(compass.state, compass.isBlueDotEnabled.compactMap { $0 })
        }
        .sink { [weak self] (state, isBlueDotEnabled) in
            guard state == .initializationComplete else {
                Log.debug("Compass: Compass Initialization Failed")
                DispatchQueue.main.async {
                    self?.consoleLog("Compass Initialization Failed")
                }
                return
            }

            Log.debug("Compass: isBlueDotEnabled: \(isBlueDotEnabled)")
            self?.currentStore = site
            self?.compass?.setStore(site)

            self?.consoleLog("Compass Initialization Succeeded")

            Log.debug("Compass: Compass initialization is success")

            guard updateStatus else {
                return
            }
            updateStatus = false
            Log.debug("Compass Initialization success")
        }
        .store(in: &cancellables)

        let errorEventEmitterCompletionHandler: (ErrorEventEmitter)->Void = { errorEventEmitter in
            let dict = errorEventEmitter.toDictionary()
            var event = [String : Any]()
            if let code = dict["errorCode"] as? Int {
                event["code"] = code
            }
            if let errortype = dict["compassErrorType"] as? String {
                event["errortype"] = errortype
            }
            if let message = dict["errorDescription"] as? String {
                event["message"] = message
            }
            DispatchQueue.main.async {
                self.consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
            }
            Log.debug("The value of errorEventEmitter is:\(errorEventEmitter)")
            Log.debug("The value of errorEventEmitter dict is:\(event)")
            guard updateStatus else { return }
            updateStatus = false
            Log.debug("-1 Compass Initialization failed")
        }

        waitForEventEmitterCompletionHandlerResponse(with: errorEventEmitterCompletionHandler)
        waitForIsFinishedSettingMapResponse()
    }
    
    func updateGlassAuthParams() {
        // Handle Glass auth parameter update without reinitializing
        guard compass != nil else {
            Log.debug("Compass is not initialized. Cannot update auth params.")
            consoleLog("Error: Compass is not initialized")
            return
        }

        prepareForAuthTypeChange(.glassLoggedIn)
        Environment.tokenType = .glass
        Environment.glassAuthType = .loggedIn
        let authParam = Environment.authParmeter

        // Update auth without reinitializing the map
        compass?.updateAuthParams(
            clientSecret: authParam.clientSecret,
            tokenType: authParam.tokenType,
            consumerID: authParam.consumerID,
            accountID: authParam.accountID,
            env: authParam.env,
            anonymizedUserId: authParam.anonymizedUserId,
            cid: authParam.CID,
            spid: authParam.SPID
        )
        self.consoleLog("Called updateAuthParams with Logged-In Glass Auth")
    }
    
    func updateAuthParamsWithGlassGuest() {
        guard compass != nil else {
            Log.debug("Compass is not initialized. Cannot update auth params.")
            consoleLog("Error: Compass is not initialized")
            return
        }

        prepareForAuthTypeChange(.glassGuest)
        Environment.tokenType = .glass
        Environment.glassAuthType = .guest
        let authParam = Environment.authParmeter

        compass?.updateAuthParams(
            clientSecret: authParam.clientSecret,
            tokenType: authParam.tokenType,
            consumerID: authParam.consumerID,
            accountID: authParam.accountID,
            env: authParam.env,
            anonymizedUserId: authParam.anonymizedUserId
        )
        self.consoleLog("Called updateAuthParams with Guest Glass Auth")
    }
    
    func updateAuthParamsWithIAM() {
        guard compass != nil else {
            Log.debug("Compass is not initialized. Cannot update auth params.")
            consoleLog("Error: Compass is not initialized")
            return
        }

        prepareForAuthTypeChange(.standardIAM)
        // Set token type to IAM
        Environment.tokenType = .IAM
        let authParam = Environment.authParmeter

        compass?.updateAuthParams(
            clientSecret: authParam.clientSecret,
            tokenType: authParam.tokenType,
            consumerID: authParam.consumerID,
            accountID: authParam.accountID
        )
        self.consoleLog("Called updateAuthParams with IAM Token")
    }
    
    func updateAuthParamsWithUser() {
        guard compass != nil else {
            Log.debug("Compass is not initialized. Cannot update auth params.")
            consoleLog("Error: Compass is not initialized")
            return
        }

        prepareForAuthTypeChange(.standardUser)
        // Set token type to User
        Environment.tokenType = .User
        let authParam = Environment.authParmeter

        compass?.updateAuthParams(
            clientSecret: authParam.clientSecret,
            tokenType: authParam.tokenType,
            consumerID: authParam.consumerID,
            accountID: authParam.accountID
        )
        self.consoleLog("Called updateAuthParams with User Token")
    }
    
    func updateAuthParamsWithPingfed() {
        guard compass != nil else {
            Log.debug("Compass is not initialized. Cannot update auth params.")
            consoleLog("Error: Compass is not initialized")
            return
        }

        prepareForAuthTypeChange(.standardPingfed)
        // Set token type to Pingfed
        Environment.tokenType = .Pingfed
        let authParam = Environment.authParmeter

        compass?.updateAuthParams(
            clientSecret: authParam.clientSecret,
            tokenType: authParam.tokenType,
            consumerID: authParam.consumerID,
            accountID: authParam.accountID
        )
        self.consoleLog("Called updateAuthParams with Pingfed Token")
    }

    private func prepareForAuthTypeChange(_ authType: AuthTypeSelection) {
        selectedAuthType = authType
        currentStore = nil
        compass?.setStore(nil)
    }
    
    func waitForEventEmitterCompletionHandlerResponse(with errorEventEmitterCompletionHandler: @escaping (ErrorEventEmitter) -> Void) {
        var statusService = compass?.getStatusService()
        statusService?.eventEmitterHandler = { [weak self] eventEmitter in
            guard let self else { return }
            switch eventEmitter.eventType {
            case .showMapEventEmitter:
                guard let eventEmitterDescription = eventEmitter as? EventEmitterDescription else {
                    return
                }

                var hashMap = eventEmitterDescription.toDictionary()
                hashMap["eventType"] = nil
                DispatchQueue.main.async {
                    self.consoleLog("SHOW MAP EVENT:\n\(hashMap.toJSONString() ?? "")")
                }
                Log.debug("The value of mapButtonEventEmitter is:\(eventEmitterDescription)")
                Log.debug("The value of mapButtonEventEmitter dict is:\(hashMap)")
            case .mapStatusEventEmitter:
                guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else { return }

                var hashMap = mapStatusEventEmitter.toDictionary()
                hashMap["eventType"] = nil
                DispatchQueue.main.async {
                    self.consoleLog("MAP STATUS EVENT:\n\(hashMap.toJSONString() ?? "")")
                }
                Log.debug("The value of mapStatusEventEmitter is:\(mapStatusEventEmitter)")
                Log.debug("The value of mapStatusEventEmitter dict is:\(hashMap)")
            case .bootstrapEventEmitter:
                guard let eventEmitterDescription = eventEmitter as? EventEmitterDescription else { return }
                self.bootstrapEventEmitterHandler?(eventEmitterDescription)
                Log.debug("The value of bootstrapEventEmitter is:\(eventEmitterDescription)")
            case .updateEventListEventEmitter:
                guard let eventEmitterDescription = eventEmitter as? EventEmitterDescription else { return }
                self.updateEventListEmitterHandler?(eventEmitterDescription)
                Log.debug("The value of bootstrapEventEmitter is:\(eventEmitterDescription)")
            case .pinListEventEmitter:
                guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                    return
                }

                self.pinDropEventEmitterHandler?(pinDropEventEmitter)
                Log.debug("The value of pinListEventEmitter is:\(pinDropEventEmitter)")

            case .pinClickedEventEmitter:
                guard let pinClickedEventEmitter = eventEmitter as? PinClickedEventEmitter else {
                    return
                }

                self.pinClickedEventEmitterHandler?(pinClickedEventEmitter)
                Log.debug("The value of pinClickedEventEmitter is:\(pinClickedEventEmitter)")

            case .aislesPinListEventEmitter:
                guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                    return
                }
                self.aislePinDropEventEmitterHandler?(pinDropEventEmitter)
                Log.debug("The value of aislesPinListEventEmitter is:\(pinDropEventEmitter)")
            case .errorEventEmitter:
                guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                    return
                }

                self.errorEventEmitterHandler?(errorEventEmitter)
                Log.debug("The value of errorEventEmitter is:\(errorEventEmitter)")
                
            case .positioningStateEventEmitter:
                guard let positioningStateEventEmitter = eventEmitter as? PositioningStateEventEmitter else {
                    return
                }
                DispatchQueue.main.async {
                    self.calibrationProgress = Double(positioningStateEventEmitter.calibrationProgress) / 100.0
                    self.positioningProgress = Double(positioningStateEventEmitter.positioningProgress) / 100.0

                    if positioningStateEventEmitter.isPositionLocked, !self.isPositionLocked {
                        self.isPositionLocked = true
                        self.consoleLog("**** POSITION LOCKED ****")
                    }
                    if !positioningStateEventEmitter.isPositionLocked && self.isPositionLocked {
                        self.isPositionLocked = false
                        self.consoleLog("**** POSITION DROPPED ****")
                        self.sendPositionDropNotification()
                    }
                }

            case .positionEventEmitter:
                guard let positionEventEmitter = eventEmitter as? PositionEventEmitter else {
                    return
                }
                if let positionType = positionEventEmitter.positionType {
                    var event = [String : Any]()

                    event["EventType"] = positionType
                    event["EventCode"] = positionEventEmitter.positionCode
                    DispatchQueue.main.async {
                        self.consoleLog("POSITIONING EVENT:\n\(event.toJSONString() ?? "")")
                    }
                    Log.debug("The value of positionEventEmitter dict is:\(event)")
                }

                if let position = positionEventEmitter.positionCode, position == 0 {
                    self.updateEvent()
                }
                Log.debug("The value of positionEventEmitter is:\(positionEventEmitter)")
            case .initErrorEventEmitter:
                guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                    return
                }

                errorEventEmitterCompletionHandler(errorEventEmitter)
            case .geofenceStateEventEmitter:
                guard let geofenceEvent = eventEmitter as? GeofenceStateEventEmitter else {
                    return
                }
                
                let newState = geofenceEvent.state
                let previousState = self.currentGeoFenceState ?? "undefined"
                
                guard previousState != newState else {
                    Log.debug("Geofence state unchanged: \(newState)")
                    return
                }
                
                switch newState {
                case "inside":
                    if previousState == "outside" || previousState == "undefined" {
                        self.sendGeoFenceEnteredNotification()
                        self.consoleLog("**** ENTERED GEOFENCE from \(previousState) ****")
                    }
                case "outside":
                    if previousState == "inside" || previousState == "undefined" {
                        self.sendGeoFenceExitedNotification()
                        self.consoleLog("**** EXITED GEOFENCE ****")
                    }
                default:
                    self.consoleLog("**** UNKNOWN state: \(newState) ****")
                }
                self.currentGeoFenceState = newState
                
            default:
                break
            }
        }
    }

    func waitForIsFinishedSettingMapResponse() {
        compass?.state
            .map { $0 == .mapLoaded }
            .sink { [weak self] isInitialize in
                guard isInitialize else {
                    Log.debug("Compass: isInitialize is not set.")
                    return
                }
                self?.compass?.displayMap(workflow: Workflow(id: "sample_app_id", type: "sample_app_flow", value: "sa_val"))
            }
            .store(in: &cancellables)
    }

    func evaluateJsExample() {
        guard let compass = compass else {
            consoleLog("evaluateJsExample: Compass is not initialized")
            return
        }
        
        let payload = "{\"type\":\"RENDER_PINS_REQUESTED\",\"payload\":{\"pinGroupingEnabled\":true,\"pins\":[{\"aisle\":1,\"selected\":true,\"type\":\"aisle-section\",\"shouldFetchData\":false,\"zone\":\"A\",\"grouped\":true,\"section\":1,\"groupedPins\":[],\"checked\":false}]}}"
        let escaped = payload.replacingOccurrences(of: "'", with: "\\'")
        compass.evaluateJSOnWebView("sendMessage('\(escaped)')")
    }
    
    func displayAssetPin(id: String) {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {return}
        setAndGetAssetsEventStatus()
        compass?.displayPin(uuidList: [id], idType: PinDropMethod.assets, config: displayPinConfig.hashMap)
    }
    
    func displayGenericPin(encodedId: String) {
        guard !encodedId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {return}
        setAndGetAssetsEventStatus()
        compass?.displayPin(uuidList: [encodedId], idType: .generic)
    }
    
    func displayPinsV2(pins: [AisleTuple], isStaticPathVisible: Bool = false) {
        var updateStatus = true

        aislePinDropEventEmitterHandler = { pinDropEventEmitter in
            var dict = pinDropEventEmitter.toDictionary()
            dict["eventType"] = nil

            Log.debug("The value of aislePinDropEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Display Pins Payload for Aisle: \(output)")
                DispatchQueue.main.async {
                    self.consoleLog("PIN DROP V2 EVENT:\n\(output)")
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
                DispatchQueue.main.async {
                    self.consoleLog("PIN CLICKED EVENT:\n\(output)")
                }
            }
        }

        var isZoomOutRequired = true
        let aislePins: [AislePin] = pins.map { tuple in
            if !tuple.zone.isEmpty && !tuple.aisle.isEmpty && !tuple.section.isEmpty {
                isZoomOutRequired = false
            }
            return AislePin(
                type: "user",
                id: UUID().uuidString,
                location: AisleLocation(
                    zone: tuple.zone,
                    aisle: tuple.aisle,
                    section: tuple.section,
                    selected: tuple.selected
                )
            )
        }
        
        if isStaticPathVisible {
            let compassPins = aislePins.map { CompassPin.aisle($0) }
            compass?.displayStaticPath(
                pins: compassPins,
                startFromNearbyEntrance: true,
                disableZoomGestures: false
            )
        } else {
            let compassPins = aislePins.map { CompassPin.aisle($0) }
            // Append a sample campaign pin for glass test
//            compassPins.append(.campaign(CampaignPin(type: "campaign", id: 2)))
            compass?.displayPin(pins: compassPins, config: displayPinConfig.hashMap)
        }
    }

    func displayCampaignPinSample() {
        let compassPins: [CompassPin] = [CompassPin.campaign(CampaignPin(type: "campaign", id: 2, selected: false))]
        compass?.displayPin(pins: compassPins, config: displayPinConfig.hashMap)
    }

    func getUserDistance(zone: String, aisle: String, section: String) {
        let trimmedZone = zone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAisle = aisle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSection = section.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedZone.isEmpty, !trimmedAisle.isEmpty, !trimmedSection.isEmpty else {
            consoleLog("Please provide zone, aisle, and section to calculate distance.")
            return
        }

        let location = compass_sdk_ios.AisleLocation(
            zone: trimmedZone,
            aisle: trimmedAisle,
            section: trimmedSection,
            selected: true
        )
        let pin = compass_sdk_ios.AislePin(
            type: "user_distance",
            id: UUID().uuidString,
            location: location
        )

        consoleLog("Requesting distance to \(trimmedZone)-\(trimmedAisle)-\(trimmedSection)")
        requestUserDistance(for: [pin])
    }
    
    func testGetUserDistanceWithHardcodedPin() {
        let pin = compass_sdk_ios.AislePin(
            type: "item",
            id: "123",
            location: compass_sdk_ios.AisleLocation(zone: "A", aisle: "1", section: "1", selected: true)
        )
        consoleLog("Called getUserDistance with hardcoded pin: \(pin)")
        requestUserDistance(for: [pin])
    }

    private func requestUserDistance(for pins: [compass_sdk_ios.AislePin]) {
        guard !pins.isEmpty else { return }

        var updateStatus = true

        aislePinDropEventEmitterHandler = { pinDropEventEmitter in
            var dict = pinDropEventEmitter.toDictionary()
            dict["eventType"] = nil

            Log.debug("The value of aislePinDropEventEmitterHandler dict is:\(dict)")
            if let output = dict.toJSONString() {
                Log.debug("Display Pins Payload for Aisle: \(output)")
                DispatchQueue.main.async {
                    self.consoleLog("PIN DROP V2 EVENT:\n\(output)")
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
                DispatchQueue.main.async {
                    self.consoleLog("PIN CLICKED EVENT:\n\(output)")
                }
            }
        }

        compass?.getUserDistance(pins: pins) { responses in
            var resultMessage = ""
            responses.forEach { response in
                let dict = response.toDictionary()
                print("User distance response is: \(dict)")
                if let output = dict.toJSONString() {
                    resultMessage += output + "\n\n"
                    DispatchQueue.main.async {
                        self.consoleLog("USER DISTANCE RESPONSE:\n\(output)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.userDistanceResult = resultMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                self.shouldShowDistanceAlert = true
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
                DispatchQueue.main.async {
                    self.consoleLog("PIN DROP EVENT:\n\(output)")
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

            var event = [String : Any]()
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
            DispatchQueue.main.async {
                self.consoleLog("ERROR EVENT:\n\(event.toJSONString() ?? "")")
            }
            guard updateStatus else {
                return
            }

            updateStatus = false
            Log.debug("-1 Compass displayPins failed")
        }
    }
}

extension HomeViewModel: WebViewMessageDelegate {
    // Conform to WebViewMessageDelegate to receive raw posted messages
    func didReceiveWebViewMessage(_ message: String) {
        Log.debug("Message from WebViewMessageDelegate (MessageParser): \(message)")
    }
}
