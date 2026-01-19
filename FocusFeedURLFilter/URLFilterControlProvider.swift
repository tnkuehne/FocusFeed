//
//  URLFilterControlProvider.swift
//  FocusFeedURLFilter
//
//  Created by Timo Kuehne on 19.01.26.
//

import ExtensionFoundation
import NetworkExtension

@main
class URLFilterControlProvider: NEURLFilterControlProvider {
    required internal init() {
    }

    func start() async throws {
        // Add code to initialize.
    }

    func stop(reason: NEProviderStopReason) async throws {
        // Add code to clean up resources.
    }

    func fetchPrefilter() async throws -> NEURLFilterPrefilter? {
        // Add code to fetch Bloom Filter and return to system
        return nil
    }
}
