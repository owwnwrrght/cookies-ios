import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    private let selectionDefaultsKey = "familyActivitySelection"
    private let appGroupId = "group.com.owenwright.Cookies"
    private static let allowanceActivity = DeviceActivityName("allowance")

    override func intervalDidStart(for activity: DeviceActivityName) {
        guard activity == Self.allowanceActivity else { return }
        recordEvent("intervalDidStart", action: "clear", selection: loadSelection())
        clearShielding()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard activity == Self.allowanceActivity else { return }
        applyShielding(eventName: "intervalDidEnd")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        guard activity == Self.allowanceActivity else { return }
        applyShielding(eventName: "intervalWillEndWarning")
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    private func loadSelection() -> FamilyActivitySelection {
        guard
            let data = defaults.data(forKey: selectionDefaultsKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private func applyShielding(eventName: String) {
        let selection = loadSelection()

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
        recordEvent(eventName, action: "apply", selection: selection)
    }

    private func clearShielding() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    private func recordEvent(_ name: String, action: String, selection: FamilyActivitySelection) {
        guard let appGroupDefaults = UserDefaults(suiteName: appGroupId) else {
#if DEBUG
            print("[DeviceActivityMonitorExtension] App group unavailable for \(name)")
#endif
            return
        }
        appGroupDefaults.set(name, forKey: "monitor.lastEvent")
        appGroupDefaults.set(action, forKey: "monitor.lastAction")
        appGroupDefaults.set(Date(), forKey: "monitor.lastEventDate")
        appGroupDefaults.set(selection.applicationTokens.count, forKey: "monitor.selection.apps")
        appGroupDefaults.set(selection.categoryTokens.count, forKey: "monitor.selection.categories")
        appGroupDefaults.set(selection.webDomainTokens.count, forKey: "monitor.selection.webDomains")
    }
}
