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

    private let store = ManagedSettingsStore()
    private let selectionDefaultsKey = "familyActivitySelection"

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        selection = Self.loadSelection(forKey: selectionDefaultsKey)
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
            return
        }

        guard !isUnlockActive else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
            store.shield.webDomains = nil
            return
        }

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
    }

    private func saveSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: selectionDefaultsKey)
    }

    private static func loadSelection(forKey key: String) -> FamilyActivitySelection {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }
}
