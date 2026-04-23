//
//  Compass.swift
//  compass_sdk_ios
//
//  Created by Rakesh Shetty on 2/17/23.
//

import Combine
import CoreData
import UIKit
import os.log
import WebKit
import SwiftUI
import IPSFramework

private class BundleLocator {}
internal let sdkBundle: Bundle = Bundle(for: BundleLocator.self)
internal let oriientBundle: Bundle = Bundle(for: IPSCore.self)

public class Compass {
    public enum InitializationState: Equatable {
        case notInitialized
        case initializationInProgress
        case initializationFailed(String)
        case initializationComplete
        case mapLoaded
    }

    internal var viewModel: CompassViewModelType!
    internal let serviceLocator: ServiceLocatorType!
    private var cancellables = Set<AnyCancellable>()
    private let stateSubject = CurrentValueSubject<InitializationState, Never>(.notInitialized)
    public internal(set) var currentStore: Int?
    public let isBlueDotEnabled = CurrentValueSubject<Bool?, Never>(nil)

    public var state: AnyPublisher<InitializationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// Initialize the Compass class.
    /// This is use to create view model.
    public init() {
        self.serviceLocator = ServiceLocator.shared
        self.viewModel = CompassViewModel(serviceLocator: serviceLocator)
    }

    internal init(serviceLocator: ServiceLocatorType, viewModel: CompassViewModelType) {
        self.serviceLocator = serviceLocator
        self.viewModel = viewModel
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Handle the events for background URL session.
    /// - Parameters:
    ///   - identifier: The identifier for the background url session.
    ///   - application: The current application instance.
    public static func handleEventsForBackgroundURLSession(identifier: String, application: UIApplication) {
        _ = IPSCore.application(application,
                            handleEventsForBackgroundURLSession: identifier,
                            completionHandler: {})
    }

    /// Initialize the Compass with authentication and configuration parameters.
    /// The authentication type (standard or glass) is determined by the tokenType in authParameter.
    ///
    /// AuthParameter Requirements by Type:
    /// - **IAM**: clientSecret, tokenType="iam", consumerID, accountID
    /// - **User**: clientSecret, tokenType="user", consumerID, accountID
    /// - **Pingfed**: clientSecret, tokenType="pingfed", consumerID, accountID
    /// - **Glass (Logged-In)**: CID, SPID, tokenType="glass", consumerID, accountID, anonymizedUserId, env
    /// - **Glass (Guest)**: clientSecret, tokenType="glass", consumerID, accountID, anonymizedUserId, env
    ///
    /// - Parameters:
    ///   - authParameter: The authentication parameter with required fields based on auth type.
    ///   - configuration: The configuration settings to apply.
    ///   - capabilities: The capabilities to enable.
    ///   - rootViewController: The root view controller to use.
    ///   - customMapRequest: Optional custom map request.
    ///   - onError: Error handler.
    public func initialize(authParameter: AuthParameter,
                           configuration: Configuration,
                           customMapRequest: URLRequest? = nil,
                           completion: @escaping (UIViewController) -> Void,
                           onError: @escaping (Error) -> Void) {
        self.stateSubject.send(.initializationInProgress)
        Analytics.anonymizedUserID = configuration.anonymizedUserID
        Analytics.initialization(state: .start)
        serviceLocator.getUserPositionManager().logout()
        Log.info("""
                Start initialize API with authParameter: \(authParameter)
                configuration: \(configuration)
                compassVersion: \(DeviceInformation.getCompassSDKVersion())
                oriientVersion: \(DeviceInformation.getOriientSDKVersion())
                """)

        var authParameter = authParameter
        self.currentStore = configuration.site
        authParameter.tokenType = authParameter.tokenType.lowercased()
        viewModel.toggleMockUser(configuration.mockUser)
        // For glass auth, set the environment
        if authParameter.tokenType == TokenType.glass.rawValue,
           let glassEnv = authParameter.env {
            self.setEnvironment(glassEnv)
        }
        #if DEBUG
        resetOverrideTracking()
        if currentStore != configuration.site {
            UserDefaults.standard.removeObject(forKey: "FeatureFlagOverrides_\(configuration.site)")
        }
        #endif
        APIPath.customStoreMapRequest = customMapRequest
        beginInitialization(authParameter: authParameter, configuration: configuration, completion: completion, onError: onError)
    }

    /// Display the map with specific workflow.
    ///
    /// - Parameters:
    ///   - workflow: The workflow to use for displaying the map.
    public func displayMap(workflow: Workflow?) {
        Log.info("Start displayMap API")
        Analytics.workflow = workflow
    }

    /// Update the event with a given compass event.
    ///
    /// - Parameters:
    ///   - compassEvent: The compass event to update.
    public func updateEvent(compassEvent: CompassEvent) {
        Log.info("Start updateEvent API with compassEvent: \(compassEvent)")
        viewModel.updateEvent(compassEvent: compassEvent)
    }

    public func updateEventList(namespace: String, eventType: String, eventValue: String, metaData: HashMap? = nil) {
        Log.info("""
                  Start updateEventList API with namespace: \(namespace)
                  eventType: \(eventType)
                  eventValue: \(eventValue)
                  metaData:\(String(describing: metaData))
                  """)

        viewModel.updateEventList(
            namespace: namespace,
            eventType: eventType,
            eventValue: eventValue,
            metaData: metaData
        )
    }

    /// Displays pins on the map with the given UUID list and configuration.
    ///
    /// - Parameters:
    ///   - uuidList: The list of UUIDs representing the assets or generic IDs
    ///   - idType: The type of ID used for the UUIDs.
    ///   - config: The configuration to apply for displaying the pins.
    public func displayPin(uuidList: [String], idType: PinDropMethod, config: HashMap? = nil) {
        Log.info("Start displayPin: \(uuidList) type: \(idType) config: \(String(describing: config))")
        viewModel.displayPin(uuidList: uuidList, idType: idType, config: DisplayPinConfig(hashMap: config))
    }

    /// Displays pins on the store map.
    ///
    /// - Parameters:
    ///   - pins: An array of `CompassPin` values (e.g. `.aisle`, `.campaign`).
    ///   - config: Optional display configuration. Keys:
    ///     - `enableManualPinDrop`: Bool — when `false`, disables manual pin placement and interactions.
    ///     - `resetZoom`: Bool — when `true`, map may reset/zoom out before rendering.
    ///     - `shouldZoomOnPins`: Bool — when `true`, map attempts to zoom/center on pins after rendering.
    ///
    /// This API is a concise, type-safe entry point for showing pins. The SDK
    /// handles conversion and transport internally; callers only need to pass
    /// the desired `CompassPin` values and an optional `config`.
    ///
    public func displayPin(pins: [CompassPin], config: HashMap? = nil) {
        Log.info("Start displayPin API with pins: \(pins), config: \(String(describing: config))")

        viewModel.displayPin(pins: pins,
                             config: DisplayPinConfig(hashMap: config))
    }

    public func displayStaticPath(pins: [CompassPin], startFromNearbyEntrance: Bool, disableZoomGestures: Bool) {
        Log.info(
            """
            Start displayStaticPath API with aisle pins: \(pins),
            startFromNearbyEntrance: \(startFromNearbyEntrance),
            disableZoomGestures: \(disableZoomGestures)
            """
        )
        viewModel.displayStaticPath(pins: pins,
                                    startFromNearbyEntrance: startFromNearbyEntrance,
                                    disableZoomGestures: disableZoomGestures)
    }

    /// Get user disctance on the map from user locatio with the given pins.
    ///
    /// - Parameters:
    ///   - pins: The list of pins representing the AislePins which contain type, id and location.
    public func getUserDistance(pins: [AislePin], completion: UserDistanceCompleteHandler? = nil) {
        Log.info("Start getUserDistance API with aisle pins: \(pins)")
        viewModel.getUserDistance(pins: pins, completion: completion)
    }

    /// Clear the map with given configuration parmater.
    ///
    /// - Parameters:
    ///   - configuration: The configration to apply for clearing the map.
    public func clearMap(configuration: HashMap? = nil) {
        Log.info("Start clearMap API with config:\(String(describing: configuration))")
        viewModel.clearMap(mapConfig: MapConfig(hashMap: configuration))
    }

    /// Register a delegate to receive raw messages posted from the embedded web page.
    ///
    /// Usage notes:
    /// - The delegate receives the web page's posted payloads as raw `String` values.
    /// - Call this after the map view is available (for example, after calling
    ///   `displayMap(...)`) so the delegate can receive messages immediately.
    ///
    /// - Parameter delegate: An object conforming to `WebViewMessageDelegate`.
    public func setWebViewMessageDelegate(_ delegate: WebViewMessageDelegate?) {
        Log.info("Start setWebViewMessageDelegate API")
        if let locator = serviceLocator as? ServiceLocator {
            if let parser = locator.getWebViewMessageParser() as? MessageParser {
                parser.webviewParserDelegate = delegate
                Log.debug("setWebViewMessageDelegate: delegate set")
            } else {
                Log.debug("setWebViewMessageDelegate: message parser is not MessageParser concrete type")
            }
        } else {
            Log.debug("setWebViewMessageDelegate: serviceLocator is not concrete ServiceLocator")
        }
    }

    /// Evaluate JavaScript on the embedded StoreMap `WKWebView`.
    ///
    /// Usage notes:
    /// - The provided string is executed exactly as given. To post a message to the
    ///   web page using the web page helper, call `evaluateJSOnWebView("sendMessage('<payload>')")`.
    /// - This method dispatches to the main thread before evaluating the script.
    /// - It does not return the evaluation result. If you need the JS evaluation
    ///   result, use the overload `evaluateJSOnWebView(_:completion:)`.
    /// - To receive message responses posted back from the web page (for example,
    ///   when the web page posts a reply to a `sendMessage(...)` call), register a
    ///   delegate via `setWebViewMessageDelegate(_:)`. The registered delegate will
    ///   receive posted string messages from the web page.
    public func evaluateJSOnWebView(_ string: String) {
        Log.info("Start evaluateJSOnWebView API with script length: \(string.count)")
        guard let webView = findStoreMapWebView() else {
            return
        }
        DispatchQueue.dispatchToMainIfNeeded {
            webView.evaluateJavaScript(string, completionHandler: nil)
        }
    }

    /// Get aisle location on map with given ID.
    ///
    /// - Parameters:
    ///   - id: The id to get aisle location.
    public func getAisle(id: String) {
        Log.info("Start getAisle API with id:\(id)")
        viewModel.getAisle(id: id)
    }

    /// Get status of the compass service.
    /// - Returns: A StatusService indicating the status of the compass service.
    public func getStatusService() -> StatusService {
        serviceLocator.getStatusService()
    }

    /// Set Environment to NetworkManager.
    /// - Parameter environment: The environment to apply for NetworkManager.
    public func setEnvironment(_ environment: CompassEnvironment) {
        Log.info("Setting environment to: \(environment.rawValue)")
        NetworkManager.environment = environment
    }

    /// Update Authentication with given token, consumer and account parameters.
    ///
    /// Required Field Validation:
    /// - **Glass (Logged-In)**: When CID and SPID are both provided (non-empty):
    ///   - CID, SPID, tokenType,accountID, anonymizedUserId, consumerID, env all required (non-empty)
    ///   - Throws `glassAuthValidation_LoggedIn` error if any required field is missing
    ///
    /// - **Glass (Guest)**: When CID and SPID are both empty:
    ///   - clientSecret, tokenType, accountID, consumerID, anonymizedUserId, env all required (non-empty)
    ///   - Throws `glassAuthValidation_Guest` error if any required field is missing
    ///
    /// - **Standard Auth** (IAM, User, Pingfed):
    ///   - clientSecret, tokenType, consumerID, accountID required
    ///   - env and anonymizedUserId optional
    ///
    /// - Parameters:
    ///   - clientSecret: The authentication secret/token for API calls. For OAuth flows, this is updated via getAccessToken().
    ///   - tokenType: The type of the token ("iam", "user", "pingfed", "glass").
    ///   - consumerID: The ID representing the consumer of the API, often used for identifying the client application.
    ///   - accountID: The ID of the account associated with the current user or session.
    ///   - env: The environment for Glass authentication (required for Glass auth).
    ///   - anonymizedUserId: The anonymized user ID (required for Glass auth).
    ///   - cid: Consumer ID for Glass logged-in users. When provided with SPID, triggers logged-in Glass auth path.
    ///   - spid: Service Provider ID for Glass logged-in users. When provided with CID, triggers logged-in Glass auth path.
    public func updateAuthParams(clientSecret: String,
                                 tokenType: String,
                                 consumerID: String,
                                 accountID: String,
                                 env: CompassEnvironment? = nil,
                                 anonymizedUserId: String? = nil,
                                 cid: String? = nil,
                                 spid: String? = nil) {
        Log.info("Updating auth parameters for consumerID: \(consumerID)")
        let tokenType = tokenType.lowercased()

        // Validate token type and required parameters
        guard tokenType == TokenType.IAM.rawValue.lowercased() ||
              tokenType == TokenType.User.rawValue ||
              tokenType == TokenType.Pingfed.rawValue ||
              tokenType == TokenType.glass.rawValue else {
            Log.error("Invalid tokenType: \(tokenType)")
            return
        }

        if tokenType == TokenType.glass.rawValue {
            updateGlassAuthParams(clientSecret: clientSecret, consumerID: consumerID, accountID: accountID,
                                env: env, anonymizedUserId: anonymizedUserId, cid: cid, spid: spid)
        } else {
            updateStandardAuthParams(clientSecret: clientSecret, tokenType: tokenType, consumerID: consumerID,
                                   accountID: accountID)
        }
    }

    ///  Use this function to refresh the compass position or reset it when needed.
    public func resetPositionStatusEvent() {
        viewModel.resetPositionStatusEvent()
    }

    ///  Use this function to remove all the compass reference.i
    public func killSwitch() {
        viewModel.killSwitch()
        self.stateSubject.send(.notInitialized)
        // Look into more state based data that needs to be cleared like UserDefaults, CoreData, StaticStorage etc.
    }

    ///  Manually start positioning session
    public func startPositioning() {
        viewModel.startPositionSession()
    }

    /// Manually stop positioning session
    public func stopPositioning() {
        viewModel.stopPositioning()
    }

    deinit {
        Log.info("Releasing compass instance.")
    }
}

private extension Compass {
    /// Begin the initialization process with provided authentication parameters and configuration.
    /// - Parameters:
    ///   - authParameter: The authentication parameter needed for initialization.
    ///   - configuration: The configuration settings for initialization.
    func beginInitialization(authParameter: AuthParameter,
                             configuration: Configuration,
                             completion: @escaping (UIViewController) -> Void,
                             onError: @escaping (Error) -> Void) {
        // Validate configuration before proceeding
        guard validateStoreInput(configuration.site) else {
            self.stateSubject.send(.initializationFailed("Not a valid store number: \(configuration.site)"))
            onError(CompassError(.initializer("Store \(configuration.site) is not valid")))
            return
        }

        viewModel.isMapViewReady()
            .sink { [weak self] isMapViewReady in
                if isMapViewReady {
                    self?.stateSubject.send(.mapLoaded)
                }
            }
            .store(in: &cancellables)

        // Fetch the access token and proceed with the initialization process
        return viewModel.getAccessToken(authParameter: authParameter)
            .flatMap { [weak self] accessTokenResponse -> AnyPublisher<StoreConfig?, Error> in
                guard accessTokenResponse != nil else {
                    let authType = authParameter.tokenType
                    Log.error("\(authType) Auth: Failed to retrieve access token")
                    Analytics.telemetry(
                        payload: TelemetryAnalytics(
                            isError: true,
                            event: CommonErrors.ERROR_INVALID_AUTH.rawValue,
                            context: CommonErrors.ErrorContext.CONTEXT_INIT.rawValue
                        )
                    )
                    return Fail(error: CompassError(.initializer("Invalid authentication response")))
                        .eraseToAnyPublisher()
                }
                Log.info("\(authParameter.tokenType) Auth: AccessTokenResponse: \(String(describing: accessTokenResponse))")
                return self?.fetchConfigurationDetails(configuration: configuration) ?? Empty()
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .filter { [weak self] config in self?.validateAndUpdateStoreConfig(config) ?? false }
            .flatMap { [weak self] storeConfig -> AnyPublisher<UIViewController, Error> in
                guard let self else {
                    onError(CompassError(.unknown("Compass class deallocated")))
                    return Empty().setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                StaticStorage.storeConfig = storeConfig
                return self.deleteAllEvents()
                    .flatMap { [weak self] _ -> AnyPublisher<UIViewController, Error> in
                        Log.info("Finished initializing API, now  fetching map.")
                        Analytics.initialization(state: .finish)
                        self?.stateSubject.send(.initializationComplete)

                        guard let mapViewController = self?.viewModel.storeMapViewController else {
                            self?.stateSubject.send(.initializationFailed("Could not initialize map view"))
                            return Empty().eraseToAnyPublisher()
                        }
                        return Just(mapViewController)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }.eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { [weak self] result in
                    switch result {
                    case .failure(let error):
                        Log.error("Failed to initialize API: \(error)")
                        self?.stateSubject.send(.initializationFailed(
                            "Initialization failed due to error: \(error.localizedDescription)"
                        ))
                        onError(error)
                    default:
                        break
                    }
                },
                receiveValue: { mapViewController in
                    Log.info("Finished fetching map. Map is ready to load.")
                    completion(mapViewController)
                    // Set map initialization flag
                    Analytics.mapInitialization(payload: BaseAnalytics(success: true))
                }).store(in: &cancellables)
    }

    /// Validates the provided configuration.
    /// - Parameter configuration: The configuration to validate.
    /// - Returns: A Boolean indicating whether the condiguration is valid.
    private func validateStoreInput(_ store: Int) -> Bool {
        guard store != 0 else {
            Log.warning("Store number is not valid, skipping init")
            Analytics.telemetry(
                payload: TelemetryAnalytics(
                    isError: true,
                    event: CommonErrors.ERROR_CONFIG_NOT_INITIALIZED.rawValue,
                    context: CommonErrors.ErrorContext.CONTEXT_INIT.rawValue
                )
            )

            Analytics.mapInitialization(
                payload: BaseAnalytics(success: false,
                                       errorCode: EventType.errorCode.rawValue,
                                       errorMessage: EventType.errorMessage.rawValue)
            )
            return false
        }
        return true
    }

    /// Fetch the configurstion details for the provided configuration.
    /// - Parameter configuration: The configuration settings to fetch details for.
    /// - Returns: A publisher that outputs the store configuration details.
    func fetchConfigurationDetails(configuration: Configuration) -> AnyPublisher<StoreConfig?, Error> {
        fetchConfiguration(for: String(configuration.site))
            .flatMap { [weak self] configResponse -> AnyPublisher<StoreConfig?, Error> in
                guard let self else {
                    Analytics.telemetry(payload: TelemetryAnalytics(
                        isError: true,
                        event: Init.INIT_ERROR_CONFIG_AUTH.rawValue
                    ))
                    return Empty(completeImmediately: true).eraseToAnyPublisher()
                }
                Analytics.telemetry(payload: TelemetryAnalytics(event: Init.INIT_CONFIG_FETCHED.rawValue))
                var resolvedStoreConfig = configResponse?.storeConfig
                if let sessionRefreshTime = configResponse?.appConfig?.sessionRefreshTime {
                    resolvedStoreConfig?.sessionRefreshTime = sessionRefreshTime
                }
                Analytics.isMapCdnEnabled = configResponse?.consumerConfig?.isMapCdnEnabled ?? false
                Analytics.isMapCompressionEnabled = configResponse?.consumerConfig?.isMapCompressionEnabled ?? false
                Analytics.mapType = resolvedStoreConfig?.mapType ?? ""
                serviceLocator.getConfigurationStoreService().setConfiguration(configuration)
                return Just(resolvedStoreConfig)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    /// Validates the store configuration and updates if valid.
    /// - Parameter storeConfig: The store configuration to valiidate and update.
    /// - Returns: A publisher that completes when the store configuration is updated.
    private func validateAndUpdateStoreConfig(_ storeConfig: StoreConfig?) -> Bool {
        guard let storeConfig, storeConfig.valid == true else {
            Log.warning("Payload storeConfig is not valid")
            Analytics.telemetry(
                payload: TelemetryAnalytics(
                    isError: true,
                    event: CommonErrors.ERROR_NOT_INITIALIZED.rawValue,
                    context: CommonErrors.ErrorContext.CONTEXT_INIT.rawValue
                )
            )
            let error: String
            if let storeConfig {
                error = "Store config is nil"
            } else {
                error = "Store config not valid"
            }
            self.stateSubject.send(.initializationFailed(error))
            return false
        }
        Log.info("StoreConfig: \(storeConfig)")
        isBlueDotEnabled.send(storeConfig.bluedotEnabled)
        viewModel.updateStoreConfiguration(storeConfig)
        prefetchFeaturePinsIfNeeded(using: storeConfig)
        return true
    }

    func prefetchFeaturePinsIfNeeded(using storeConfig: StoreConfig) {
        guard let storeId = storeConfig.storeId,
              storeConfig.resolvedPins.featurePinEnabled else {
            return
        }

        let assetService = serviceLocator.getAssetService()
        assetService.cancelFeaturePinsForOtherStores(currentStoreId: storeId)
        assetService.fetchFeaturePins(storeId: storeId, storeConfig: storeConfig) { result in
            if case .failure(let error) = result {
                Log.debug("[FeaturePin] Prefetch failed during init: \(error.localizedDescription)")
            }
        }
    }

    /// Will also retrieve configuration based on storeId, consumerId, timestamp and access token.
    ///
    /// - Parameters:
    ///   - storeId: The storeId to be used to get configuration
    ///   - consumerId: The consumerId to be used to get configuration
    ///   - timestamp: The timestamp to be used to get configuration
    ///   - accessTokenResponse: The accessTokenResponse to be used to get configuration
    func fetchConfiguration(for storeId: String) -> AnyPublisher<ConfigurationPayload?, Error> {
        serviceLocator.getConfigurationService()
            .getConfigData(for: storeId)
            .retry()
            .catch { [weak self] error -> AnyPublisher<ConfigurationPayload?, Error> in
                Log.error(error)
                guard let error = error as? ErrorResponse else {
                    return Fail(error: error).eraseToAnyPublisher()
                }

                self?.serviceLocator.getStatusService().emitErrorStatusEvent(for: error, isInitError: true)
                return Fail(error: error).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func deleteAllEvents() -> AnyPublisher<Void, Error> {
        serviceLocator.getEventStoreService().deleteAllEvents()
    }

    func findStoreMapWebView() -> WKWebView? {
        if let registered = (serviceLocator as? ServiceLocator)?.getRegisteredStoreMapsViewController() {
            return registered.mapView.webView
        }

        return nil
    }

    private func updateGlassAuthParams(clientSecret: String, consumerID: String, accountID: String,
                                       env: CompassEnvironment?, anonymizedUserId: String?,
                                       cid: String?, spid: String?) {
        let isLoggedInUser = !(cid?.isEmpty ?? true) && !(spid?.isEmpty ?? true)

        if isLoggedInUser {
            guard !consumerID.isEmpty,
                  !accountID.isEmpty,
                  let cid = cid, !cid.isEmpty,
                  let spid = spid, !spid.isEmpty else {
                Log.error("Logged-in Glass Auth validation failed: Missing required fields")
                return
            }

            let authParameter = AuthParameter(clientSecret: clientSecret,
                                              tokenType: TokenType.glass.rawValue,
                                              accountID: accountID,
                                              consumerID: consumerID,
                                              env: env,
                                              anonymizedUserId: anonymizedUserId,
                                              CID: cid,
                                              SPID: spid)
            fetchAndUpdateAuthToken(authParameter: authParameter, authType: "logged-in Glass")
        } else {
            guard !clientSecret.isEmptyOrWhitespace(),
                  !consumerID.isEmpty else {
                Log.error("Guest Glass Auth validation failed: Missing required fields")
                return
            }

            let authParameter = AuthParameter(clientSecret: clientSecret,
                                              tokenType: TokenType.glass.rawValue,
                                              accountID: accountID,
                                              consumerID: consumerID,
                                              env: env,
                                              anonymizedUserId: anonymizedUserId)
            fetchAndUpdateAuthToken(authParameter: authParameter, authType: "guest Glass")
        }
    }

    private func updateStandardAuthParams(clientSecret: String, tokenType: String, consumerID: String, accountID: String) {
        if tokenType == TokenType.IAM.rawValue.lowercased() {
            guard !clientSecret.isEmpty, !consumerID.isEmpty else {
                Log.error("IAM Auth validation failed: Missing required fields")
                return
            }
        }

        let authParameter = AuthParameter(clientSecret: clientSecret,
                                          tokenType: tokenType,
                                          accountID: accountID,
                                          consumerID: consumerID)
        fetchAndUpdateAuthToken(authParameter: authParameter, authType: tokenType)
    }

    private func fetchAndUpdateAuthToken(authParameter: AuthParameter, authType: String) {
        var cancellable: AnyCancellable?
        cancellable = viewModel.getAccessToken(authParameter: authParameter)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Log.error("Failed to get access token for \(authType) auth: \(error.localizedDescription)")
                }
                cancellable?.cancel()
            }, receiveValue: { accessTokenResponse in
                if accessTokenResponse != nil {
                    Log.info("Successfully obtained access token for \(authType) auth")
                } else {
                    Log.error("Access token response is nil for \(authType) auth")
                }
                cancellable?.cancel()
            })
    }
}
