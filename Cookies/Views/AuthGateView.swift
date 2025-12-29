//
//  AuthGateView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI
import FirebaseAuth

struct AuthGateView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @EnvironmentObject private var timeAllowanceManager: TimeAllowanceManager
    @EnvironmentObject private var userProfileManager: UserProfileManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var usageSessionManager = UsageSessionManager()
    @AppStorage("hasCompletedAuthFlow") private var hasCompletedAuthFlow = false

    private let timeZoneDidChange = NotificationCenter.default.publisher(
        for: .NSSystemTimeZoneDidChange
    )

    var body: some View {
        Group {
            if !hasCompletedAuthFlow || authViewModel.user == nil {
                SignInView()
            } else if authViewModel.user != nil {
                if userProfileManager.hasLoadedProfile {
                    if userProfileManager.hasCompletedOnboarding {
                        HomeView()
                    } else {
                        CookieOnboardingView()
                    }
                } else {
                    ProgressView("Loading...")
                }
            }
        }
        .onChange(of: authViewModel.user?.uid) { _, newValue in
            if let userId = newValue {
                userProfileManager.startListening(userId: userId)
                userProfileManager.updateTimezoneOffsetMinutes(userId: userId)
                usageSessionManager.updateUser(userId: userId)
                timeAllowanceManager.setUserId(userId)
                AnalyticsManager.logEvent("auth_session_active")
            } else {
                userProfileManager.stopListening()
                usageSessionManager.updateUser(userId: nil)
                timeAllowanceManager.setUserId(nil)
                AnalyticsManager.logEvent("auth_session_inactive")
            }
        }
        .onChange(of: timeAllowanceManager.isUnlockActive) { _, newValue in
            screenTimeManager.isUnlockActive = newValue
            usageSessionManager.setUnlockActive(newValue)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            if let userId = authViewModel.user?.uid {
                userProfileManager.updateTimezoneOffsetMinutes(userId: userId)
            }
        }
        .onReceive(timeZoneDidChange) { _ in
            if let userId = authViewModel.user?.uid {
                userProfileManager.updateTimezoneOffsetMinutes(userId: userId)
            }
        }
        .onAppear {
            screenTimeManager.isUnlockActive = timeAllowanceManager.isUnlockActive
            usageSessionManager.setUnlockActive(timeAllowanceManager.isUnlockActive)
            if let userId = authViewModel.user?.uid {
                userProfileManager.startListening(userId: userId)
                userProfileManager.updateTimezoneOffsetMinutes(userId: userId)
                usageSessionManager.updateUser(userId: userId)
                timeAllowanceManager.setUserId(userId)
            }
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(AuthViewModel())
        .environmentObject(ScreenTimeManager())
        .environmentObject(TimeAllowanceManager())
        .environmentObject(UserProfileManager())
}
