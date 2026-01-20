//
//  FilterManager.swift
//  FocusFeed
//
//  Created by Claude on 19.01.26.
//

import NetworkExtension
import Observation

@Observable
@MainActor
class FilterManager {
    var isEnabled = false
    var status = "Not configured"
    var isLoading = false

    static let extensionBundleIdentifier = "com.timokuehne.FocusFeed.FocusFeedURLFilter"

    init() {
        Task {
            await loadCurrentState()
        }
    }

    func loadCurrentState() async {
        let manager = NEURLFilterManager.shared

        do {
            try await manager.loadFromPreferences()
            isEnabled = manager.isEnabled
            status = manager.isEnabled ? "Filter active" : "Filter disabled"
        } catch {
            status = "Not configured"
        }
    }

    func setupFilter() async throws {
        isLoading = true
        defer { isLoading = false }

        let manager = NEURLFilterManager.shared

        do {
            try await manager.loadFromPreferences()
        } catch {
            // No existing config, that's fine
        }

        // Configure the filter
        manager.localizedDescription = "YouTube Shorts Blocker"
        manager.isEnabled = true
        manager.prefilterFetchInterval = 3600 // 1 hour

        try await manager.saveToPreferences()

        isEnabled = true
        status = "Filter active"
    }

    func disableFilter() async throws {
        isLoading = true
        defer { isLoading = false }

        let manager = NEURLFilterManager.shared

        try await manager.loadFromPreferences()
        manager.isEnabled = false
        try await manager.saveToPreferences()

        isEnabled = false
        status = "Filter disabled"
    }

    func toggleFilter() async {
        do {
            if isEnabled {
                try await disableFilter()
            } else {
                try await setupFilter()
            }
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }
}
