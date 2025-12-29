//
//  CookieOnboardingView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI
import FirebaseAuth
import FamilyControls

struct CookieOnboardingView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var userProfileManager: UserProfileManager
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager

    @StateObject private var nfcScanner = NFCScanner()

    @State private var step: OnboardingStep = .claimPack
    @State private var statusMessage: String?

    @State private var isScanning = false
    @State private var hasClaimedPack = false

    @State private var cookieMinutes = 30.0

    @State private var isRequestingScreenTime = false

    @State private var isPickerPresented = false
    @State private var isCompleting = false

    private let packService = CookiePackService()

    var body: some View {
        ZStack {
            Color("CookiesBackground")
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Text("Set Up Cookies")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color("CookiesTextPrimary"))
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                if let statusMessage {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text(statusMessage)
                    }
                    .font(.footnote)
                    .foregroundColor(Color("CookiesTextSecondary"))
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }

                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color("CookiesBackground"))
                            .frame(width: 80, height: 80)

                        Image(systemName: step.iconName)
                            .font(.system(size: 36))
                            .foregroundColor(Color("CookiesTextPrimary"))
                    }
                    .padding(.top, 10)

                    VStack(spacing: 8) {
                        Text(step.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("CookiesTextPrimary"))
                            .multilineTextAlignment(.center)

                        Text(step.subtitle)
                            .font(.subheadline)
                            .foregroundColor(Color("CookiesTextSecondary"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Divider()

                    switch step {
                    case .claimPack:
                        claimPackContent
                    case .cookieValues:
                        cookieValuesContent
                    case .enableScreenTime:
                        enableScreenTimeContent
                    case .selectApps:
                        selectAppsContent
                    }
                }
                .padding(24)
                .background(Color("CookiesSurface"))
                .cornerRadius(20)
                .shadow(color: Color("Lead").opacity(0.08), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(OnboardingStep.allCases, id: \.self) { s in
                        Circle()
                            .fill(step == s ? Color("CookiesAccent") : Color("CookiesSurfaceAlt").opacity(0.6))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $screenTimeManager.selection)
        .onAppear {
            cookieMinutes = Double(userProfileManager.cookieValues[CookieType.cookie.rawValue] ?? 30)

            nfcScanner.onTokenRead = { tokenId in
                claimPack(cookieId: tokenId)
            }
            nfcScanner.onError = { message in
                statusMessage = message
                isScanning = false
            }

            screenTimeManager.refreshAuthorizationStatus()
            AnalyticsManager.logScreen("Onboarding", className: "CookieOnboardingView")
            AnalyticsManager.logEvent("onboarding_step_view", parameters: [
                "step": step.rawValue
            ])
        }
        .onChange(of: step) { _, newValue in
            AnalyticsManager.logEvent("onboarding_step_view", parameters: [
                "step": newValue.rawValue
            ])
        }
    }
}

private extension CookieOnboardingView {
    var claimPackContent: some View {
        VStack(spacing: 16) {
            Button(action: {
                beginScan()
            }) {
                HStack {
                    if isScanning {
                        ProgressView().progressViewStyle(
                            CircularProgressViewStyle(tint: Color("CookiesButtonText"))
                        )
                    } else {
                        Image(systemName: hasClaimedPack ? "checkmark" : "wave.3.right")
                        Text(hasClaimedPack ? "Pack Claimed" : "Scan Cookie")
                    }
                }
                .font(.headline)
                .foregroundColor(Color("CookiesButtonText"))
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 55)
                .background(hasClaimedPack ? Color.green : Color("CookiesButtonFill"))
                .clipShape(Capsule())
            }
            .disabled(isScanning || hasClaimedPack)

            if hasClaimedPack {
                continueButton {
                    withAnimation { step = .cookieValues }
                }
            }
        }
    }

    var cookieValuesContent: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Time per cookie")
                    .font(.headline)
                    .foregroundColor(Color("CookiesTextPrimary"))
                Spacer()
                Text("\(Int(cookieMinutes)) min")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color("CookiesTextPrimary"))
            }

            Slider(value: $cookieMinutes, in: 15...120, step: 5)
                .accentColor(Color("CookiesAccent"))

            continueButton {
                withAnimation { step = .enableScreenTime }
            }
        }
    }

    var enableScreenTimeContent: some View {
        VStack(spacing: 16) {
            if screenTimeManager.authorizationStatus == .approved {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Access Enabled")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Color("CookiesTextPrimary"))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color("CookiesSurfaceAlt"))
                .clipShape(Capsule())
            }

            Button(action: {
                requestScreenTimeAccess()
            }) {
                HStack {
                    if isRequestingScreenTime {
                        ProgressView().progressViewStyle(
                            CircularProgressViewStyle(tint: Color("CookiesButtonText"))
                        )
                    } else {
                        Text(screenTimeManager.authorizationStatus == .approved ? "Access Granted" : "Allow Access")
                    }
                }
                .font(.headline)
                .foregroundColor(Color("CookiesButtonText"))
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 55)
                .background(screenTimeManager.authorizationStatus == .approved ? Color.green : Color("CookiesButtonFill"))
                .clipShape(Capsule())
            }
            .disabled(isRequestingScreenTime || screenTimeManager.authorizationStatus == .approved)

            if screenTimeManager.authorizationStatus == .approved {
                continueButton {
                    withAnimation { step = .selectApps }
                }
            }
        }
    }

    var selectAppsContent: some View {
        VStack(spacing: 16) {
            if screenTimeManager.hasSelection {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Apps Selected")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Color("CookiesTextPrimary"))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color("CookiesSurfaceAlt"))
                .clipShape(Capsule())
            }

            Button(action: {
                isPickerPresented = true
                AnalyticsManager.logEvent("screentime_picker_opened")
            }) {
                Text(screenTimeManager.hasSelection ? "Edit Apps" : "Choose Apps")
                    .font(.headline)
                    .foregroundColor(Color("CookiesButtonText"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .frame(height: 55)
                    .background(Color("CookiesButtonFill"))
                    .clipShape(Capsule())
            }

            Button(action: {
                completeOnboarding()
            }) {
                HStack {
                    if isCompleting {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color("CookiesAccent")))
                    } else {
                        Text("Finish Setup")
                    }
                }
                .font(.headline)
                .foregroundColor(Color("CookiesTextPrimary"))
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 55)
                .background(Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color("CookiesAccent").opacity(0.2), lineWidth: 1))
            }
            .disabled(isCompleting)
        }
    }

    func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .font(.headline)
                .foregroundColor(Color("CookiesTextPrimary"))
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 55)
                .background(Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color("CookiesAccent").opacity(0.2), lineWidth: 1))
        }
    }
}

private extension CookieOnboardingView {
    func beginScan() {
        statusMessage = nil
        isScanning = true
        AnalyticsManager.logEvent("pack_scan_started")
        nfcScanner.beginScanning()
    }

    func claimPack(cookieId: String) {
        guard let userId = authViewModel.user?.uid else {
            statusMessage = "You must be signed in to claim a pack."
            isScanning = false
            return
        }

        Task {
            do {
                try await packService.claimPack(cookieId: cookieId, userId: userId)
                await MainActor.run {
                    isScanning = false
                    hasClaimedPack = true
                    statusMessage = "Pack claimed successfully."
                    AnalyticsManager.logEvent("pack_claim_success")
                }
            } catch {
                await MainActor.run {
                    isScanning = false
                    statusMessage = error.localizedDescription
                    AnalyticsManager.logEvent("pack_claim_failed")
                }
            }
        }
    }

    func requestScreenTimeAccess() {
        isRequestingScreenTime = true
        AnalyticsManager.logEvent("screentime_request_started")
        Task {
            await screenTimeManager.requestAuthorization()
            await MainActor.run {
                isRequestingScreenTime = false
                AnalyticsManager.logEvent("screentime_request_completed", parameters: [
                    "authorized": screenTimeManager.authorizationStatus == .approved
                ])
            }
        }
    }

    func completeOnboarding() {
        guard let userId = authViewModel.user?.uid else {
            statusMessage = "You must be signed in to finish setup."
            return
        }

        isCompleting = true
        let minutesValue = Int(cookieMinutes)
        let values: [String: Int] = [
            CookieType.cookie.rawValue: minutesValue
        ]

        userProfileManager.updateCookieValues(userId: userId, values: values) { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    isCompleting = false
                    statusMessage = error.localizedDescription
                    AnalyticsManager.logEvent("onboarding_finish_failed")
                }
                return
            }

            userProfileManager.markOnboardingComplete(userId: userId) { result in
                DispatchQueue.main.async {
                    isCompleting = false
                    if case .failure(let error) = result {
                        statusMessage = error.localizedDescription
                        AnalyticsManager.logEvent("onboarding_finish_failed")
                    } else {
                        AnalyticsManager.logEvent("onboarding_finish_success")
                    }
                }
            }
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case claimPack = 0
    case cookieValues
    case enableScreenTime
    case selectApps

    var title: String {
        switch self {
        case .claimPack: return "Claim Your Pack"
        case .cookieValues: return "Set Cookie Value"
        case .enableScreenTime: return "Enable Screen Time"
        case .selectApps: return "Choose Apps"
        }
    }

    var subtitle: String {
        switch self {
        case .claimPack: return "Scan any cookie in your pack to verify ownership."
        case .cookieValues: return "Choose how many minutes each cookie adds."
        case .enableScreenTime: return "Grant permission to manage app limits."
        case .selectApps: return "Select the apps to block when time runs out."
        }
    }

    var iconName: String {
        switch self {
        case .claimPack: return "tag.fill"
        case .cookieValues: return "clock.fill"
        case .enableScreenTime: return "hourglass"
        case .selectApps: return "lock.app.dashed"
        }
    }
}

#Preview {
    CookieOnboardingView()
        .environmentObject(AuthViewModel())
        .environmentObject(UserProfileManager())
        .environmentObject(ScreenTimeManager())
}
