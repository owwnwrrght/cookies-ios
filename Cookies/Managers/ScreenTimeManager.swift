//
//  ScreenTimeManager.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import Combine
import FamilyControls
import ManagedSettings

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection {
        didSet {
            saveSelection()
            applyShielding()
        }
    }
    @Published var isUnlockActive = false {
        didSet {
            applyShielding()
        }
    }
    @Published var ultraHardcoreMode: Bool {
        didSet {
            UserDefaults.standard.set(ultraHardcoreMode, forKey: Self.ultraHardcoreModeKey)
            applyShielding()
        }
    }

    private let store = ManagedSettingsStore()
    private static let ultraHardcoreModeKey = "ultraHardcoreMode"
    private static let selectionDefaultsKey = "familyActivitySelection"
    private let appGroupId = "group.com.owenwright.Cookies"
    private let appGroupDefaults: UserDefaults?

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        appGroupDefaults = UserDefaults(suiteName: appGroupId)
        ultraHardcoreMode = UserDefaults.standard.bool(forKey: Self.ultraHardcoreModeKey)
        selection = Self.loadSelection(appGroupDefaults: appGroupDefaults)
        saveSelection()
        applyShielding()
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    @MainActor
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // Authorization errors are surfaced via status updates.
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        applyShielding()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func refreshShielding() {
        applyShielding()
    }

    private func applyShielding() {
        guard authorizationStatus == .approved else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
            store.shield.webDomains = nil
            store.application.denyAppRemoval = false
            return
        }

        guard !isUnlockActive else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
            store.shield.webDomains = nil
            store.application.denyAppRemoval = false
            return
        }

        // Blocking is active
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens
        store.shield.webDomainCategories = nil

        // Ultra Hardcore: prevent app deletion while blocking is active
        store.application.denyAppRemoval = ultraHardcoreMode
    }

    private func saveSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        if let appGroupDefaults {
            appGroupDefaults.set(data, forKey: Self.selectionDefaultsKey)
            UserDefaults.standard.removeObject(forKey: Self.selectionDefaultsKey)
        } else {
            UserDefaults.standard.set(data, forKey: Self.selectionDefaultsKey)
        }
    }

    private static func loadSelection(appGroupDefaults: UserDefaults?) -> FamilyActivitySelection {
        if let data = appGroupDefaults?.data(forKey: selectionDefaultsKey),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            return selection
        }
        if let data = UserDefaults.standard.data(forKey: selectionDefaultsKey),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            if let appGroupDefaults {
                appGroupDefaults.set(data, forKey: selectionDefaultsKey)
                UserDefaults.standard.removeObject(forKey: selectionDefaultsKey)
            }
            return selection
        }
        return FamilyActivitySelection()
    }
}
