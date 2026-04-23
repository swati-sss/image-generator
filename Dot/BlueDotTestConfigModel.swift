//
//  ConfigurationPayload.swift
//  compass_sdk_ios
//
//  Created by Rakesh Shetty on 2/18/23.
//

import Foundation

struct AppConfig: Codable {
    var sessionRefreshTime: Int?

    init(sessionRefreshTime: Int? = nil) {
        self.sessionRefreshTime = sessionRefreshTime
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case sessionRefreshTime
    }
}

struct ConfigurationPayload: Codable {
    var consumerConfig: ConsumerConfig?
    var storeConfig: StoreConfig?
    var appConfig: AppConfig?

    init(
        consumerConfig: ConsumerConfig? = nil,
        storeConfig: StoreConfig? = nil,
        appConfig: AppConfig? = nil
    ) {
        self.consumerConfig = consumerConfig
        self.storeConfig = storeConfig
        self.appConfig = appConfig
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case consumerConfig
        case storeConfig
        case appConfig
    }
}
