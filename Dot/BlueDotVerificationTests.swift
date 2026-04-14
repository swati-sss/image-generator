//
//  BlueDotVerificationTests.swift
//  compass_sdk_iosTests
//

import Combine
import IPSFramework
import UIKit
import XCTest
@testable import compass_sdk_ios

private let _blueDotEnvironmentSetup: Void = {
    if let path = Bundle(for: BlueDotVerificationTests.self).path(forResource: "BlueDotTestConfig", ofType: "json"),
       let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
       let config = try? JSONDecoder().decode(BlueDotTestConfig.self, from: data) {
        NetworkManager.environment = config.compassEnvironment
    }
}()

private struct RuntimeBlueDotSignalResult {
    let mapLoaded: Bool
    let userLocationRenderedReceived: Bool
    let userLocationRequestedReceived: Bool
    let blueDotDisplayed: Bool
}

private struct ConfigFetchOutcome {
    let payload: ConfigurationPayload?
    let error: Error?
    let didTimeOut: Bool
}

private final class RuntimeWebViewMessageTracker: NSObject, WebViewMessageDelegate {
    private let lock = NSLock()
    private let onBlueDotDisplayed: () -> Void
    private var hasSignaledSuccess = false

    private var mapLoaded = false
    private var userLocationRendered = false
    private var userLocationRequested = false

    init(onBlueDotDisplayed: @escaping () -> Void) {
        self.onBlueDotDisplayed = onBlueDotDisplayed
    }

    func didReceiveWebViewMessage(_ message: String) {
        guard
            let data = message.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        switch type {
        case "MAP_LOADED":
            mapLoaded = true
        case "USER_LOCATION_RENDERED":
            guard mapLoaded else { return }
            userLocationRendered = true
            signalSuccessIfNeededLocked()
        case "USER_LOCATION_REQUESTED":
            guard mapLoaded else { return }
            userLocationRequested = true
            signalSuccessIfNeededLocked()
        default:
            break
        }
    }

    func snapshot() -> (mapLoaded: Bool, userLocationRendered: Bool, userLocationRequested: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (mapLoaded, userLocationRendered, userLocationRequested)
    }

    private func signalSuccessIfNeededLocked() {
        guard !hasSignaledSuccess else { return }
        guard mapLoaded, userLocationRendered || userLocationRequested else { return }
        hasSignaledSuccess = true
        DispatchQueue.main.async {
            self.onBlueDotDisplayed()
        }
    }
}

private final class RuntimeCompassServiceLocator: ServiceLocatorType {
    static var shared: ServiceLocatorType { ServiceLocator.shared }

    private let base: ServiceLocatorType
    private lazy var networkService: NetworkServiceType = NetworkService()
    private lazy var configurationService: ConfigurationService = ConfigurationServiceImpl(
        configurationStoreService: base.getConfigurationStoreService(),
        networkService: networkService
    )
    private var storeMapViewModel: StoreMapViewActionable?
    private var messageSender: MessageSending?
    private var messageParser: MessageParsing?
    private var compassViewModel: CompassViewModelType?
    private weak var registeredStoreMapsViewController: StoreMapsViewController?

    init(base: ServiceLocatorType = ServiceLocator.shared) {
        self.base = base
    }

    func getLocationPermissionService() -> LocationPermissionService {
        base.getLocationPermissionService()
    }

    func getNetworkMonitorService() -> NetworkMonitorService {
        base.getNetworkMonitorService()
    }

    func getIndoorPositioningService() -> IndoorPositioningService {
        base.getIndoorPositioningService()
    }

    func getIndoorNavigationService() -> IndoorNavigationService {
        base.getIndoorNavigationService()
    }

    func getStaticPathPreviewService() -> StaticPathPreviewService {
        base.getStaticPathPreviewService()
    }

    func getMapFocusManager() -> MapFocusManager {
        base.getMapFocusManager()
    }

    func getStatusService() -> StatusService {
        base.getStatusService()
    }

    func getEventService() -> EventService {
        base.getEventService()
    }

    func getAssetService() -> AssetService {
        base.getAssetService()
    }

    func getEventStoreService() -> EventStoreService {
        base.getEventStoreService()
    }

    func getConfigurationStoreService() -> ConfigurationStoreService {
        base.getConfigurationStoreService()
    }

    func getConfigurationService() -> ConfigurationService {
        configurationService
    }

    func getLogEventStoreService() -> LogEventStoreService {
        base.getLogEventStoreService()
    }

    func getLogDefaultImpl() -> LogDefault {
        base.getLogDefaultImpl()
    }

    func getUserPositionManager() -> any UserPositionManagement {
        base.getUserPositionManager()
    }

    func getNetworkService() -> any NetworkServiceType {
        networkService
    }

    func getStoreMapViewModel(
        blueDotMode: BlueDotMode,
        storeMapOptions: StoreMapView.Options,
        debugLog: DebugLog?
    ) -> StoreMapViewActionable {
        guard let storeMapViewModel else {
            self.storeMapViewModel = StoreMapLoaderViewModel(
                blueDotMode: blueDotMode,
                storeMapOptions: storeMapOptions,
                debugLog: debugLog,
                serviceLocator: self
            )
            return getStoreMapViewModel(
                blueDotMode: blueDotMode,
                storeMapOptions: storeMapOptions,
                debugLog: debugLog
            )
        }

        #if DEBUG
        if let loaderViewModel = storeMapViewModel as? StoreMapLoaderViewModel {
            loaderViewModel.updateConfiguration(
                pinsConfig: storeMapOptions.pinsConfig,
                navigationConfig: storeMapOptions.navigationConfig
            )
        }
        #endif

        return storeMapViewModel
    }

    func getCompassViewModel() -> any CompassViewModelType {
        guard let compassViewModel else {
            self.compassViewModel = CompassViewModel(serviceLocator: self)
            return getCompassViewModel()
        }

        return compassViewModel
    }

    func getWebViewMessageSender() -> any MessageSending {
        guard let messageSender else {
            self.messageSender = MessageSender()
            return getWebViewMessageSender()
        }

        return messageSender
    }

    func getWebViewMessageParser() -> MessageParsing {
        guard let messageParser else {
            self.messageParser = MessageParser()
            return getWebViewMessageParser()
        }

        return messageParser
    }

    func destroy() {
        storeMapViewModel = nil
        messageSender = nil
        messageParser = nil
        compassViewModel = nil
        registeredStoreMapsViewController = nil
    }

    func registerStoreMapsViewController(_ vc: StoreMapsViewController?) {
        registeredStoreMapsViewController = vc
    }

    func getRegisteredStoreMapsViewController() -> StoreMapsViewController? {
        registeredStoreMapsViewController
    }
}

private final class RuntimeMapHost {
    private let window = UIWindow(frame: UIScreen.main.bounds)
    private let rootViewController = UIViewController()
    private weak var mapViewController: UIViewController?

    init() {
        window.rootViewController = rootViewController
        window.windowLevel = .normal
        window.makeKeyAndVisible()
        rootViewController.loadViewIfNeeded()
        rootViewController.beginAppearanceTransition(true, animated: false)
        rootViewController.endAppearanceTransition()
    }

    func attach(_ viewController: UIViewController) {
        mapViewController = viewController
        rootViewController.addChild(viewController)
        viewController.loadViewIfNeeded()
        viewController.view.frame = rootViewController.view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        rootViewController.view.addSubview(viewController.view)
        viewController.didMove(toParent: rootViewController)
        rootViewController.view.setNeedsLayout()
        rootViewController.view.layoutIfNeeded()
    }

    func tearDown() {
        mapViewController?.willMove(toParent: nil)
        mapViewController?.view.removeFromSuperview()
        mapViewController?.removeFromParent()
        rootViewController.beginAppearanceTransition(false, animated: false)
        rootViewController.endAppearanceTransition()
        window.isHidden = true
    }
}

final class BlueDotVerificationTests: XCTestCase {
    private var testConfig: BlueDotTestConfig!

    override func setUpWithError() throws {
        try super.setUpWithError()
        _ = _blueDotEnvironmentSetup
        testConfig = loadTestConfig()
        NetworkManager.environment = testConfig.compassEnvironment
        StaticStorage.authParameter = nil
        StaticStorage.storeConfig = nil
        ServiceLocator.shared.destroy()
    }

    override func tearDownWithError() throws {
        ServiceLocator.shared.destroy()
        StaticStorage.authParameter = nil
        StaticStorage.storeConfig = nil
        testConfig = nil
        try super.tearDownWithError()
    }

    func testBluedotEndToEnd() throws {
        print("")
        print("Blue Dot End-to-End Verification")
        print(String(repeating: "-", count: 58))
        print("Environment: \(testConfig.testEnvironment)")
        print("Total Stores: \(testConfig.testStores.count)")
        print("")

        let authParameter = testConfig.authParameter
        let enabledFlags = testConfig.getEnabledFlags()
        let userLocationRenderedFlagNames = enabledFlags.filter { isUserLocationRenderedFlag($0) }
        let mapLoadedRuntimeFlagNames = enabledFlags.filter { normalizedFlagName($0) == "maploaded" }
        let buildingMatchFlagNames = enabledFlags.filter { isBuildingNameMatchFlag($0) }

        let shouldCheckRuntimeBlueDotSignals = !userLocationRenderedFlagNames.isEmpty || !mapLoadedRuntimeFlagNames.isEmpty
        let shouldCheckBuildingNameMatch = !buildingMatchFlagNames.isEmpty
        let buildingLookupTimeout = TimeInterval(testConfig.verificationTimeout)
        let buildingCheckUserId = testConfig.accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Credentials.userID
            : testConfig.accountID

        print("Enabled flags for testing: \(enabledFlags.joined(separator: ", "))")
        if shouldCheckRuntimeBlueDotSignals {
            print("Runtime blue-dot signal checks enabled for: \((mapLoadedRuntimeFlagNames + userLocationRenderedFlagNames).joined(separator: ", "))")
        }
        if shouldCheckBuildingNameMatch {
            print("Building name match check enabled for flags: \(buildingMatchFlagNames.joined(separator: ", "))")
            print("Building checks will login per store with userId: \(buildingCheckUserId)")
        }

        var endToEndReport: [(storeId: Int, flagResults: [String: Bool?])] = []

        for storeId in testConfig.testStores {
            print("")
            print("Store \(storeId):")

            let fetchOutcome = fetchStoreConfig(for: storeId, authParameter: authParameter)
            let payload = fetchOutcome.payload
            var flagResults = evaluateConfigFlags(enabledFlags: enabledFlags, storeId: storeId, payload: payload)
            let configBlueDotEnabled = payload?.storeConfig?.bluedotEnabled

            var statusMessages: [String] = []
            for flagName in enabledFlags {
                let value = flagResults[flagName] ?? nil
                let status = value.map { $0 ? "PASS" : "FAIL" } ?? "SKIP"
                statusMessages.append("\(flagName): \(value.map { String($0) } ?? "n/a") [\(status)]")
            }
            print("  Config results: \(statusMessages.joined(separator: " | "))")

            if let error = fetchOutcome.error {
                print("  Config request error: \(error.localizedDescription)")
            } else if fetchOutcome.didTimeOut {
                print("  Config request timed out")
            }

            if shouldCheckBuildingNameMatch {
                if loginForBuildingChecks(userId: buildingCheckUserId, timeout: buildingLookupTimeout) {
                    var buildingResult = fetchBuildingNameMatch(for: storeId, timeout: buildingLookupTimeout)

                    if buildingResult.isMatch == nil {
                        print("  Retrying building lookup after re-login for store \(storeId)")
                        if loginForBuildingChecks(userId: buildingCheckUserId, timeout: buildingLookupTimeout) {
                            buildingResult = fetchBuildingNameMatch(for: storeId, timeout: buildingLookupTimeout)
                        }
                    }

                    for flagName in buildingMatchFlagNames {
                        flagResults[flagName] = buildingResult.isMatch
                    }

                    if let buildingName = buildingResult.buildingName, let isMatch = buildingResult.isMatch {
                        let status = isMatch ? "PASS" : "FAIL"
                        print("  Building name: \(buildingName)")
                        print("  Building name contains store id: \(isMatch) [\(status)]")
                    } else {
                        print("  Building match unavailable for store \(storeId)")
                    }
                } else {
                    for flagName in buildingMatchFlagNames {
                        flagResults[flagName] = nil
                    }
                    print("  Building match skipped due to Oriient login failure")
                }
            }

            if shouldCheckRuntimeBlueDotSignals {
                let hasConfigRuntimePrerequisites = configBlueDotEnabled != nil
                let runtimePrerequisitesMet = configBlueDotEnabled == true

                if hasConfigRuntimePrerequisites && !runtimePrerequisitesMet {
                    print("  Runtime blue-dot verification skipped because bluedotEnabled is false")
                    for flagName in mapLoadedRuntimeFlagNames {
                        flagResults[flagName] = false
                    }
                    for flagName in userLocationRenderedFlagNames {
                        flagResults[flagName] = false
                    }
                } else if !hasConfigRuntimePrerequisites {
                    print("  Runtime blue-dot verification skipped because bluedotEnabled is missing")
                } else {
                    let runtimeResult = verifyBlueDotRuntimeSignals(
                        for: storeId,
                        authParameter: authParameter,
                        timeout: TimeInterval(testConfig.verificationTimeout)
                    )

                    for flagName in mapLoadedRuntimeFlagNames {
                        flagResults[flagName] = runtimeResult.mapLoaded
                    }
                    for flagName in userLocationRenderedFlagNames {
                        flagResults[flagName] = runtimeResult.blueDotDisplayed
                    }

                    print("  Runtime MAP_LOADED: \(runtimeResult.mapLoaded)")
                    print("  Runtime USER_LOCATION_RENDERED: \(runtimeResult.userLocationRenderedReceived)")
                    print("  Runtime USER_LOCATION_REQUESTED: \(runtimeResult.userLocationRequestedReceived)")
                    print("  Runtime blue-dot displayed: \(runtimeResult.blueDotDisplayed)")
                }
            }

            endToEndReport.append((storeId: Int(storeId), flagResults: flagResults))
            ServiceLocator.shared.getIndoorPositioningService().logout()
            ServiceLocator.shared.destroy()
            StaticStorage.authParameter = nil
            StaticStorage.storeConfig = nil
            Thread.sleep(forTimeInterval: 0.1)
        }

        print("")
        print(String(repeating: "-", count: 70))
        print("FINAL REPORT: End-to-End Verification")
        print(String(repeating: "-", count: 70))
        print("")
        print("SUMMARY:")
        print("  Total Stores Tested: \(endToEndReport.count)")

        for flagName in enabledFlags {
            let enabledCount = endToEndReport.filter { $0.flagResults[flagName] == true }.count
            print("  \(flagName): \(enabledCount)/\(endToEndReport.count) PASS")
        }

        print("")
        print("DETAILED RESULTS:")
        for entry in endToEndReport {
            let flagStatuses = enabledFlags.map { flagName -> String in
                let value = entry.flagResults[flagName] ?? nil
                let status = value.map { $0 ? "PASS" : "FAIL" } ?? "SKIP"
                return "\(flagName)[\(status)]"
            }
            print("Store \(entry.storeId): \(flagStatuses.joined(separator: " "))")
        }
        print(String(repeating: "-", count: 70))
        print("")
    }

    private func fetchStoreConfig(for storeId: Int, authParameter: AuthParameter) -> ConfigFetchOutcome {
        StaticStorage.authParameter = authParameter
        NetworkManager.environment = testConfig.compassEnvironment

        let expectation = XCTestExpectation(description: "Fetch config for store \(storeId)")
        let configService = ConfigurationServiceImpl(
            configurationStoreService: ServiceLocator.shared.getConfigurationStoreService(),
            networkService: NetworkService()
        )

        var payload: ConfigurationPayload?
        var receivedError: Error?
        var cancellable: AnyCancellable?

        print("  Requesting config for store \(storeId)")
        print("  Auth type: \(authParameter.tokenType)")
        print("  Consumer ID: \(authParameter.consumerID)")
        print("  Account ID: \(authParameter.accountID)")

        cancellable = configService.getConfigData(for: String(storeId))
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                }
                expectation.fulfill()
            }, receiveValue: { configPayload in
                payload = configPayload
                if let configPayload,
                   let data = try? JSONEncoder().encode(configPayload),
                   let jsonString = String(data: data, encoding: .utf8) {
                    print("  Config payload preview: \(jsonString.prefix(500))...")
                }
            })

        let result = XCTWaiter().wait(for: [expectation], timeout: 5.0)
        cancellable?.cancel()

        return ConfigFetchOutcome(
            payload: payload,
            error: receivedError,
            didTimeOut: result != .completed
        )
    }

    private func evaluateConfigFlags(
        enabledFlags: [String],
        storeId: Int,
        payload: ConfigurationPayload?
    ) -> [String: Bool?] {
        var flagResults: [String: Bool?] = [:]
        let storeConfig = payload?.storeConfig

        if let storeConfig {
            print("  StoreConfig bluedotEnabled: \(storeConfig.bluedotEnabled ?? false)")
            print("  StoreConfig dynamicMapEnabled: \(storeConfig.dynamicMapEnabled ?? false)")
            print("  StoreConfig zoomControlEnabled: \(storeConfig.zoomControlEnabled ?? false)")
            print("  StoreConfig spinnerEnabled: \(storeConfig.spinnerEnabled ?? false)")
            print("  StoreConfig errorScreensEnabled: \(storeConfig.errorScreensEnabled ?? false)")
            if let navigation = storeConfig.navigation {
                print("  StoreConfig navigation.enabled: \(navigation.enabled ?? false)")
                print("  StoreConfig navigation.isAutomaticNavigation: \(navigation.isAutomaticNavigation)")
            }
        } else {
            print("  StoreConfig is nil for store \(storeId)")
        }

        for flagName in enabledFlags {
            switch normalizedFlagName(flagName) {
            case "bluedotenabled":
                flagResults[flagName] = storeConfig?.bluedotEnabled
            case "navigationenabled":
                if let navigation = storeConfig?.navigation {
                    flagResults[flagName] = navigation.enabled
                } else {
                    flagResults[flagName] = storeConfig?.navigationEnabled
                }
            case "isdynamicmapenabled", "dynamicmapenabled":
                flagResults[flagName] = storeConfig?.dynamicMapEnabled
            case "isautomaticnavigation":
                flagResults[flagName] = storeConfig?.navigation?.isAutomaticNavigation
            case "maploaded":
                flagResults[flagName] = nil
            case "orientloaded", "locationupdates":
                print("  \(flagName) is not available in StoreConfig payload and requires runtime validation")
                flagResults[flagName] = nil
            case "zoomcontrolenabled":
                flagResults[flagName] = storeConfig?.zoomControlEnabled
            case "spinnerenabled":
                flagResults[flagName] = storeConfig?.spinnerEnabled
            case "errorscreensenabled":
                flagResults[flagName] = storeConfig?.errorScreensEnabled
            case "buildingnamematch", "buildingmatch", "buildingnamecontainsstoreid":
                flagResults[flagName] = nil
            case "oriientenabled", "orientenabled":
                flagResults[flagName] = storeConfig?.mapType == MapIdentifier.OriientMap.rawValue
            case "userlocationrendered", "bluedotvisibleonmap", "bluedotdisplayed", "bluedotdisplayedonmap":
                flagResults[flagName] = nil
            default:
                print("  Unknown flag: \(flagName) - skipping")
                flagResults[flagName] = nil
            }
        }

        return flagResults
    }

    private func verifyBlueDotRuntimeSignals(
        for storeId: Int,
        authParameter: AuthParameter,
        timeout: TimeInterval
    ) -> RuntimeBlueDotSignalResult {
        let runtimeTimeout = max(timeout, 20.0)
        let initExpectation = XCTestExpectation(description: "Initialize runtime map verification for store \(storeId)")
        let runtimeExpectation = XCTestExpectation(description: "Wait for runtime map signals for store \(storeId)")

        let tracker = RuntimeWebViewMessageTracker {
            runtimeExpectation.fulfill()
        }
        let runtimeServiceLocator = RuntimeCompassServiceLocator()
        let runtimeViewModel = CompassViewModel(serviceLocator: runtimeServiceLocator)
        let compass = Compass(serviceLocator: runtimeServiceLocator, viewModel: runtimeViewModel)
        var mapViewController: UIViewController?
        var host: RuntimeMapHost?
        var initError: Error?

        DispatchQueue.main.async {
            compass.setEnvironment(self.testConfig.compassEnvironment)
            StaticStorage.authParameter = authParameter
            if let parser = runtimeServiceLocator.getWebViewMessageParser() as? MessageParser {
                parser.webviewParserDelegate = tracker
            }

            let runtimeHost = RuntimeMapHost()
            host = runtimeHost

            compass.initialize(
                authParameter: authParameter,
                configuration: self.makeRuntimeConfiguration(for: storeId),
                completion: { returnedMapViewController in
                    DispatchQueue.main.async {
                        mapViewController = returnedMapViewController
                        runtimeHost.attach(returnedMapViewController)
                        compass.displayMap(
                            workflow: Workflow(
                                id: "bluedot_runtime_check",
                                type: "bluedot_verification",
                                value: "\(storeId)"
                            )
                        )
                        initExpectation.fulfill()
                    }
                },
                onError: { error in
                    initError = error
                    initExpectation.fulfill()
                }
            )
        }

        let initResult = XCTWaiter().wait(for: [initExpectation], timeout: runtimeTimeout)

        guard initResult == .completed, initError == nil, mapViewController != nil else {
            if let initError {
                print("  Runtime initialization failed for store \(storeId): \(initError.localizedDescription)")
            } else {
                print("  Runtime initialization timed out for store \(storeId)")
            }

            let snapshot = tracker.snapshot()
            cleanupRuntimeCompass(
                compass: compass,
                host: host,
                runtimeServiceLocator: runtimeServiceLocator
            )
            return RuntimeBlueDotSignalResult(
                mapLoaded: snapshot.mapLoaded,
                userLocationRenderedReceived: snapshot.userLocationRendered,
                userLocationRequestedReceived: snapshot.userLocationRequested,
                blueDotDisplayed: false
            )
        }

        _ = XCTWaiter().wait(for: [runtimeExpectation], timeout: runtimeTimeout)
        let snapshot = tracker.snapshot()
        cleanupRuntimeCompass(
            compass: compass,
            host: host,
            runtimeServiceLocator: runtimeServiceLocator
        )

        let blueDotDisplayed = snapshot.mapLoaded && (snapshot.userLocationRendered || snapshot.userLocationRequested)

        return RuntimeBlueDotSignalResult(
            mapLoaded: snapshot.mapLoaded,
            userLocationRenderedReceived: snapshot.userLocationRendered,
            userLocationRequestedReceived: snapshot.userLocationRequested,
            blueDotDisplayed: blueDotDisplayed
        )
    }

    private func makeRuntimeConfiguration(for storeId: Int) -> Configuration {
        let userId = testConfig.accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Credentials.userID
            : testConfig.accountID

        return Configuration(
            country: "US",
            site: storeId,
            userId: userId,
            siteType: .Store,
            manualPinDrop: true,
            navigateToPin: false,
            multiPin: false,
            searchBar: false,
            centerMap: true,
            locationIngestion: true,
            mockUser: testConfig.mockUserEnabled,
            anonymizedUserID: "bluedot-verification-\(storeId)",
            startPositioning: true,
            automaticCalibration: true,
            businessUnitType: .WALMART
        )
    }

    private func cleanupRuntimeCompass(
        compass: Compass,
        host: RuntimeMapHost?,
        runtimeServiceLocator: RuntimeCompassServiceLocator
    ) {
        let cleanupExpectation = XCTestExpectation(description: "Cleanup runtime verification resources")

        DispatchQueue.main.async {
            if let parser = runtimeServiceLocator.getWebViewMessageParser() as? MessageParser {
                parser.webviewParserDelegate = nil
            }
            compass.killSwitch()
            ServiceLocator.shared.getIndoorPositioningService().logout()
            host?.tearDown()
            runtimeServiceLocator.destroy()
            ServiceLocator.shared.registerStoreMapsViewController(nil)
            ServiceLocator.shared.destroy()
            StaticStorage.authParameter = nil
            StaticStorage.storeConfig = nil
            cleanupExpectation.fulfill()
        }

        _ = XCTWaiter().wait(for: [cleanupExpectation], timeout: 5.0)
    }

    private func loginForBuildingChecks(userId: String, timeout: TimeInterval) -> Bool {
        let loginExpectation = XCTestExpectation(description: "Oriient login for building checks")
        let indoorPositioningService = ServiceLocator.shared.getIndoorPositioningService()
        var loginSucceeded = false

        indoorPositioningService.login(userId: userId) { error in
            if let error {
                print("  Oriient login failed: code=\(error.code.rawValue), message=\(error.message)")
                loginSucceeded = false
            } else {
                print("  Oriient login succeeded for building checks")
                loginSucceeded = true
            }
            loginExpectation.fulfill()
        }

        let result = XCTWaiter().wait(for: [loginExpectation], timeout: timeout)
        guard result == .completed else {
            print("  Oriient login timed out")
            return false
        }

        return loginSucceeded
    }

    private func fetchBuildingNameMatch(
        for storeId: Int,
        timeout: TimeInterval
    ) -> (buildingName: String?, isMatch: Bool?) {
        let indoorPositioningService = ServiceLocator.shared.getIndoorPositioningService()
        let buildingExpectation = XCTestExpectation(description: "Fetch building for store \(storeId)")
        var buildingName: String?
        var isMatch: Bool?

        indoorPositioningService.getBuilding(
            "\(storeId)",
            onSuccess: { building in
                ServiceLocator.shared.getIndoorNavigationService().setBuilding(building)
                buildingName = building.name
                isMatch = building.name.contains("\(storeId)")
                buildingExpectation.fulfill()
            },
            onError: { error in
                print("  Building lookup failed for store \(storeId): code=\(error.code.rawValue), message=\(error.message)")
                buildingExpectation.fulfill()
            }
        )

        let result = XCTWaiter().wait(for: [buildingExpectation], timeout: timeout)
        guard result == .completed else {
            print("  Building lookup timed out for store \(storeId)")
            return (nil, nil)
        }

        return (buildingName, isMatch)
    }

    private func isBuildingNameMatchFlag(_ flagName: String) -> Bool {
        switch normalizedFlagName(flagName) {
        case "buildingnamematch", "buildingmatch", "buildingnamecontainsstoreid":
            return true
        default:
            return false
        }
    }

    private func isUserLocationRenderedFlag(_ flagName: String) -> Bool {
        switch normalizedFlagName(flagName) {
        case "userlocationrendered", "bluedotvisibleonmap", "bluedotdisplayed", "bluedotdisplayedonmap":
            return true
        default:
            return false
        }
    }

    private func normalizedFlagName(_ rawFlagName: String) -> String {
        rawFlagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .lowercased()
    }

    private func loadTestConfig() -> BlueDotTestConfig {
        if let bundleURL = Bundle(for: type(of: self)).url(forResource: "BlueDotTestConfig", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let config = try? JSONDecoder().decode(BlueDotTestConfig.self, from: data) {
            return config
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("BlueDotTestConfig.json")

        if let data = try? Data(contentsOf: sourceURL),
           let config = try? JSONDecoder().decode(BlueDotTestConfig.self, from: data) {
            return config
        }

        fatalError("BlueDotTestConfig.json not found in the test bundle or the BlueDot source directory")
    }
}
