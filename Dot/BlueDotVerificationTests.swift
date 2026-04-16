//
//  UserPositionManager.swift
//  compass_sdk_ios
//
//  Created by Pratik Patel on 1/15/24.
//

import Combine
import IPSFramework

protocol UserPositionManagement: AnyObject {
    var building: IPSBuilding? { get }

    init(serviceLocator: ServiceLocatorType)
    func getUserPosition() -> AnyPublisher<User, Never>
    func startPositioning()
    func stopPositioning(reason: String?, completion: (() -> Void)?)
    func logout()
}

extension UserPositionManagement {
    func stopPositioning(reason: String? = nil) {
        stopPositioning(reason: reason, completion: nil)
    }
}

final class UserPositionManager: UserPositionManagement {
    enum LoginState {
        case loggedOut
        case loginInProgress
        case loggedIn
    }

    private let indoorPositioningService: IndoorPositioningService
    private let indoorNavigationService: IndoorNavigationService
    private let staticPathPreviewService: StaticPathPreviewService
    private let sessionStorage: SessionStorable.Type
    private var buildingSelectionCancellable: AnyCancellable?
    private var oriientLoginState: LoginState = .loggedOut
    @Published private(set) var building: IPSBuilding?

    required init(serviceLocator: ServiceLocatorType) {
        indoorPositioningService = serviceLocator.getIndoorPositioningService()
        sessionStorage = serviceLocator.getSessionStorage()
        indoorNavigationService = serviceLocator.getIndoorNavigationService()
        staticPathPreviewService = serviceLocator.getStaticPathPreviewService()
    }

    deinit {
        logout()
    }

    func startPositioning() {
        switch oriientLoginState {
        case .loggedIn:
            initiateBuildingSelection()
        case .loggedOut:
            loginToOriient()
        default:
            break
        }
    }

    func stopPositioning(reason: String?, completion: (() -> Void)?) {
        indoorPositioningService.stopPositioning(reason: reason) { [weak self] error in
            self?.handleStopPositioningResult(error, completion: completion)
        }
        clearBuildingSelection()
    }

    func getUserPosition() -> AnyPublisher<User, Never> {
        indoorPositioningService.lastPosition
            .receive(on: DispatchQueue.main)
            .map { [weak self] position in
                guard let self,
                      let lastPosition = self.indoorPositioningService.lastLockedPosition else {
                    return User(position: nil, state: .hidden)
                }

                if let position {
                    return User(position: position, state: position.isLocked ? .locked : .lostLock)
                }
                return User(position: lastPosition, state: .lostLock)
            }.eraseToAnyPublisher()
    }

    func logout() {
        indoorPositioningService.logout()
        oriientLoginState = .loggedOut
        building = nil
        buildingSelectionCancellable?.cancel()
        buildingSelectionCancellable = nil
    }
}

private extension UserPositionManager {
    func clearBuildingSelection() {
        buildingSelectionCancellable?.cancel()
        buildingSelectionCancellable = nil
    }

    func handleStopPositioningResult(_ error: IPSError?, completion: (() -> Void)?) {
        DispatchQueue.dispatchToMainIfNeeded {
            defer {
                completion?()
            }

            guard error == nil else {
                self.clearBuildingSelection()
                return
            }

            Log.info("Finished Stop Positioning")
            self.indoorNavigationService.resetWaypoints(shouldClearBlueDot: true, shouldClearPinList: true)
            self.clearBuildingSelection()
        }
    }

    func startIndoorPositioning(building: IPSBuilding) {
        indoorPositioningService.startPositioning(building: building) { err in
            if let err {
                Log.error("Start positioning failed with error: \(err)")
            }
            let buildingName = building.clientBuildingId ?? building.displayName
            Log.info("Start Positioning in building: \(buildingName) floor: \(building.primaryFloor.name)")
        }
    }

    func loginToOriient() {
        guard oriientLoginState == .loggedOut else {
            return
        }
        oriientLoginState = .loginInProgress
        Analytics.initialization(state: .login)

        let userId = sessionStorage.configuration?.anonymizedUserID ?? "compass user"
        self.indoorPositioningService.login(userId: userId) { [weak self] error in
            DispatchQueue.dispatchToMainIfNeeded {
                if let error {
                    Log.error("Oriient login failed: \(error.code): \(error.message): \(error.recoveryStrategy)")
                    error.sendToTelemetry(context: .IPS_CONTEXT_LOGIN)
                    return
                }
                Analytics.telemetry(payload: TelemetryAnalytics(event: Init.INIT_ORIIENT_LOGIN.rawValue))
                Log.info("Finish Oriient Login with userId: \(userId)")
                self?.oriientLoginState = .loggedIn
                self?.initiateBuildingSelection()
            }
        }
    }

    func initiateBuildingSelection() {
        guard oriientLoginState == .loggedIn else {
            Log.error("Cannot initiate building selection, user is not logged in.")
            return
        }

        buildingSelectionCancellable?.cancel()
        if let building,
           building.clientBuildingId?.trimmingCharacters(in: .whitespacesAndNewlines) == "\(sessionStorage.storeId)" {
            startIndoorPositioning(building: building)
            return
        }

        Analytics.initialization(state: .mapDownload)
        Analytics.telemetry(payload: TelemetryAnalytics(
            event: Init.INIT_ORIIENT_BUILDING_SEARCH.rawValue
        ))
        self.indoorPositioningService.getBuilding("\(sessionStorage.storeId)") { [weak self] building in
            DispatchQueue.dispatchToMainIfNeeded {
                self?.building = building
                self?.indoorNavigationService.setBuilding(building)
                self?.staticPathPreviewService.setBuilding(building)
                self?.startIndoorPositioning(building: building)
            }
        } onError: { error in
            DispatchQueue.dispatchToMainIfNeeded {
                Log.error("Error fetching building metadata: \(error)")
                error.sendToTelemetry(context: .IPS_CONTEXT_BUILDING_SEARCH)
            }
        }
    }
}
