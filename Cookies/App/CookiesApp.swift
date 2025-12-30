//
//  CookiesApp.swift
//  Cookies
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
#if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.error)
#endif
        configureAppCheck()
        FirebaseApp.configure()
#if DEBUG
        Analytics.setAnalyticsCollectionEnabled(false)
#endif
        configureFirebaseEmulatorsIfNeeded()
        application.registerForRemoteNotifications()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification notification: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }

    private func configureFirebaseEmulatorsIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        guard env["USE_FIREBASE_EMULATORS"] == "1" else { return }

        if let authHost = env["FIREBASE_AUTH_EMULATOR_HOST"],
           let (host, port) = hostAndPort(authHost) {
            Auth.auth().useEmulator(withHost: host, port: port)
        }

        if let firestoreHost = env["FIRESTORE_EMULATOR_HOST"],
           let (host, port) = hostAndPort(firestoreHost) {
            Firestore.firestore().useEmulator(withHost: host, port: port)
        }
    }

    private func hostAndPort(_ value: String) -> (String, Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        return (String(parts[0]), port)
    }

    private func configureAppCheck() {
#if DEBUG
        let env = ProcessInfo.processInfo.environment
        if env["USE_REAL_APP_CHECK"] == "1" {
#if targetEnvironment(simulator)
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
#endif
            return
        }
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
#endif
    }
}

enum AnalyticsManager {
    static func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    static func logScreen(_ name: String, className: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: className
        ])
    }

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}

@main
struct CookiesApp: App {
    // Register app delegate for Firebase setup.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var screenTimeManager = ScreenTimeManager()
    @StateObject private var timeAllowanceManager = TimeAllowanceManager()
    @StateObject private var userProfileManager = UserProfileManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationView {
                AuthGateView()
            }
            .environmentObject(authViewModel)
            .environmentObject(screenTimeManager)
            .environmentObject(timeAllowanceManager)
            .environmentObject(userProfileManager)
        }
        .onChange(of: timeAllowanceManager.remainingSeconds) { remaining in
            let shouldUnlock = remaining > 0
            if screenTimeManager.isUnlockActive != shouldUnlock {
                screenTimeManager.isUnlockActive = shouldUnlock
            }
            if remaining <= 0 {
                screenTimeManager.refreshShielding()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                timeAllowanceManager.refresh()
                screenTimeManager.refreshAuthorizationStatus()
                screenTimeManager.isUnlockActive = timeAllowanceManager.remainingSeconds > 0
                screenTimeManager.refreshShielding()
            } else if phase == .background || phase == .inactive {
                timeAllowanceManager.refresh()
                if timeAllowanceManager.remainingSeconds <= 0 {
                    screenTimeManager.isUnlockActive = false
                    screenTimeManager.refreshShielding()
                }
            }
        }
    }
}
