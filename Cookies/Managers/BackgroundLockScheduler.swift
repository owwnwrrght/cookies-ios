//
//  BackgroundLockScheduler.swift
//  Cookies
//
//  Created by Owen Wright on 12/19/25.
//

import BackgroundTasks
import FamilyControls
import Foundation
import ManagedSettings

enum BackgroundLockScheduler {
    static let taskIdentifier = "com.owenwright.Cookies.allowanceLockRefresh"

    private static let selectionDefaultsKey = "familyActivitySelection"
    private static let lastUserIdKey = "allowanceLastUserId"
    private static let pendingEndDateKey = "allowanceEndDate.pending"
    private static let store = ManagedSettingsStore()

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    static func scheduleNextCheck(endDate: Date?) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        guard let endDate, endDate > Date() else { return }

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = endDate

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
#if DEBUG
            print("[BackgroundLockScheduler] Failed to schedule refresh: \(error)")
#endif
        }
    }

    static func refreshLockStateIfNeeded() {
        let endDate = loadEndDate()
        let now = Date()
        let unlockActive = endDate.map { $0 > now } ?? false

        applyShielding(isUnlockActive: unlockActive)
        scheduleNextCheck(endDate: unlockActive ? endDate : nil)
    }

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {}
        refreshLockStateIfNeeded()
        task.setTaskCompleted(success: true)
    }

    private static func loadEndDate() -> Date? {
        let defaults = UserDefaults.standard
        if let lastUserId = defaults.string(forKey: lastUserIdKey) {
            return defaults.object(forKey: "allowanceEndDate.\(lastUserId)") as? Date
        }
        return defaults.object(forKey: pendingEndDateKey) as? Date
    }

    private static func loadSelection() -> FamilyActivitySelection {
        guard
            let data = UserDefaults.standard.data(forKey: selectionDefaultsKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private static func applyShielding(isUnlockActive: Bool) {
        let authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        let selection = loadSelection()

        guard authorizationStatus == .approved else {
            clearShielding()
            return
        }

        guard !isUnlockActive else {
            clearShielding()
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

    private static func clearShielding() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
