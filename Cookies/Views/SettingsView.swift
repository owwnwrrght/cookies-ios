//
//  SettingsView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI
import FamilyControls
import FirebaseAuth
import SafariServices
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var screenTimeManager: ScreenTimeManager
    @EnvironmentObject private var timeAllowanceManager: TimeAllowanceManager
    @EnvironmentObject private var userProfileManager: UserProfileManager
    @State private var isPickerPresented = false
    @State private var showDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var isUnlockingEmergency = false
    @State private var emergencyMessage: String?
    @State private var showShareSheet = false
    @State private var activeAlertMessage: String?
    @State private var activeSafariLink: SafariLink?
    @State private var cookieMinutes = 30.0
    @State private var isSavingCookieValue = false
    @State private var isEditingCookieValue = false

    var body: some View {
        ZStack {
            Color("CookiesBackground")
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account")
                            .font(.headline)
                            .foregroundColor(Color("CookiesTextPrimary"))

                        Text(accountLabel)
                            .font(.subheadline)
                            .foregroundColor(Color("CookiesTextSecondary"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color("CookiesSurface"))
                    .cornerRadius(16)

//                    VStack(alignment: .leading, spacing: 12) {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Share cookie with a Friend")
//                                .font(.headline)
//                                .foregroundColor(Color("CookiesTextPrimary"))
//                            Text("Your referral gets 10% off in their order!")
//                                .font(.subheadline)
//                                .foregroundColor(Color("CookiesTextSecondary"))
//                        }
//
//                        Button(action: {
//                            showShareSheet = true
//                        }) {
//                            Text("Refer a friend now")
//                                .font(.subheadline)
//                                .fontWeight(.medium)
//                                .foregroundColor(Color("CookiesTextPrimary"))
//                                .frame(maxWidth: .infinity)
//                                .padding(.vertical, 14)
//                                .background(Color("CookiesButtonFill").opacity(0.08))
//                                .clipShape(Capsule())
//                        }
//                    }
//                    .padding(20)
//                    .background(Color("CookiesSurface"))
//                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emergency Snack")
                                .font(.headline)
                                .foregroundColor(Color("CookiesTextPrimary"))
                            Text(emergencyStatusText)
                                .font(.subheadline)
                                .foregroundColor(Color("CookiesTextSecondary"))
                        }

                        Divider()

                        Button(action: {
                            useEmergencyUnlock()
                        }) {
                            HStack(spacing: 10) {
                                if isUnlockingEmergency {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(tint: Color("CookiesButtonText"))
                                        )
                                }
                                Text("Use emergency snack")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(userProfileManager.canUseEmergencyUnlock
                                             ? Color("CookiesButtonText")
                                             : Color("CookiesTextSecondary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(userProfileManager.canUseEmergencyUnlock
                                        ? Color("CookiesButtonFill")
                                        : Color("CookiesSurfaceAlt"))
                            .clipShape(Capsule())
                        }
                        .disabled(isUnlockingEmergency || !userProfileManager.canUseEmergencyUnlock)
                    }
                    .padding(20)
                    .background(Color("CookiesSurface"))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cookie Value")
                            .font(.headline)
                            .foregroundColor(Color("CookiesTextPrimary"))

                        Text(cookieValueStatusText)
                            .font(.subheadline)
                            .foregroundColor(Color("CookiesTextSecondary"))

                        HStack {
                            Text("Minutes per cookie")
                                .font(.subheadline)
                                .foregroundColor(Color("CookiesTextPrimary"))
                            Spacer()
                            Text("\(cookieMinutesValue) min")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("CookiesTextPrimary"))
                        }

                        Slider(
                            value: $cookieMinutes,
                            in: 15...120,
                            step: 5,
                            onEditingChanged: { isEditingCookieValue = $0 }
                        )
                        .accentColor(Color("CookiesAccent"))
                        .disabled(!timeAllowanceManager.isUnlockActive)
                        .opacity(timeAllowanceManager.isUnlockActive ? 1 : 0.6)

                        Button(action: {
                            saveCookieValue()
                        }) {
                            HStack(spacing: 10) {
                                if isSavingCookieValue {
                                    ProgressView()
                                        .progressViewStyle(
                                            CircularProgressViewStyle(tint: Color("CookiesButtonText"))
                                        )
                                }
                                Text("Save cookie value")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(timeAllowanceManager.isUnlockActive
                                             ? Color("CookiesButtonText")
                                             : Color("CookiesTextSecondary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(timeAllowanceManager.isUnlockActive
                                        ? Color("CookiesButtonFill")
                                        : Color("CookiesSurfaceAlt"))
                            .clipShape(Capsule())
                        }
                        .disabled(isSavingCookieValue || !timeAllowanceManager.isUnlockActive || !isCookieValueDirty)
                    }
                    .padding(20)
                    .background(Color("CookiesSurface"))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Blocked Apps")
                            .font(.headline)
                            .foregroundColor(Color("CookiesTextPrimary"))

                        Text(blockedAppsStatusText)
                            .font(.subheadline)
                            .foregroundColor(Color("CookiesTextSecondary"))

                        Button(action: {
                            isPickerPresented = true
                            AnalyticsManager.logEvent("blocked_apps_edit_opened")
                        }) {
                            Text("Edit blocked apps")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(timeAllowanceManager.isUnlockActive ? Color("CookiesTextPrimary") : Color("CookiesTextSecondary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color("CookiesButtonFill").opacity(timeAllowanceManager.isUnlockActive ? 0.08 : 0.04))
                                .clipShape(Capsule())
                        }
                        .disabled(!timeAllowanceManager.isUnlockActive)
                    }
                    .padding(20)
                    .background(Color("CookiesSurface"))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("About cookie")
                            .font(.headline)
                            .foregroundColor(Color("CookiesTextPrimary"))
                            .padding(.bottom, 10)

                        SettingsRow(title: "Why cookie?") {
                            openWebLink(.whyCookies)
                        }
                        Divider()
                        SettingsRow(title: "Privacy Policy") {
                            openWebLink(.privacy)
                        }
                    }
                    .padding(20)
                    .background(Color("CookiesSurface"))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Questions")
                            .font(.headline)
                            .foregroundColor(Color("CookiesTextPrimary"))
                            .padding(.bottom, 10)

                        SettingsRow(title: "Troubleshooting") {
                            openWebLink(.troubleshooting)
                        }
                        Divider()
                        SettingsRow(title: "Get Help") {
                            openWebLink(.help)
                        }
                        Divider()
                        SettingsRow(title: "Delete account") {
                            showDeleteAlert = true
                        }
                    }
                    .padding(20)
                    .background(Color("CookiesSurface"))
                    .cornerRadius(16)

                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        Text("Sign out")
                            .font(.headline)
                            .foregroundColor(Color("CookiesTextPrimary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("CookiesButtonFill").opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 10)

                    Text(appVersionLabel)
                        .font(.caption)
                        .foregroundColor(Color("CookiesTextSecondary"))
                        .padding(.top, 4)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $screenTimeManager.selection)
        .sheet(item: $activeSafariLink) { link in
            SafariView(url: link.url)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareMessage])
        }
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete your account and registered cookies.")
        }
        .alert("Error", isPresented: Binding(
            get: { activeAlertMessage != nil },
            set: { _ in activeAlertMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(activeAlertMessage ?? "Something went wrong.")
        }
        .onAppear {
            AnalyticsManager.logScreen("Settings", className: "SettingsView")
            syncCookieMinutes()
        }
        .onChange(of: userProfileManager.cookieValues) { _, _ in
            syncCookieMinutes()
        }
    }
}

private extension SettingsView {
    var accountLabel: String {
        if let phoneNumber = authViewModel.user?.phoneNumber {
            return "Signed in as \(phoneNumber)"
        }
        return "Signed in"
    }

    var shareMessage: String {
        "Claim extra screen time with me on Cookies."
    }

    var blockedAppsStatusText: String {
        if timeAllowanceManager.isUnlockActive {
            return "You can update blocked apps while your timer is running."
        }
        return "Start a timer to edit blocked apps."
    }

    var cookieValueStatusText: String {
        if timeAllowanceManager.isUnlockActive {
            return "Update how many minutes each cookie adds."
        }
        return "Start a timer to change cookie value."
    }

    var emergencyStatusText: String {
        if let emergencyMessage {
            return emergencyMessage
        }
        if userProfileManager.canUseEmergencyUnlock {
            return "Available now"
        }
        if let next = userProfileManager.nextEmergencyUnlockDate {
            return "Available on \(formattedDate(next))"
        }
        return "Unavailable"
    }

    var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "Version \(version) (\(build))"
    }

    var cookieMinutesValue: Int {
        Int(cookieMinutes.rounded())
    }

    var currentCookieMinutes: Int {
        userProfileManager.cookieValues[CookieType.cookie.rawValue] ?? 30
    }

    var isCookieValueDirty: Bool {
        cookieMinutesValue != currentCookieMinutes
    }

    var websiteBaseURL: String {
        let fallback = "https://cookies-c6de0.web.app"
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CookiesWebsiteBaseURL") as? String else {
            return fallback
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func useEmergencyUnlock() {
        guard !isUnlockingEmergency else { return }
        guard userProfileManager.canUseEmergencyUnlock else { return }
        guard let userId = authViewModel.user?.uid else {
            activeAlertMessage = "You must be signed in to use the emergency unlock."
            return
        }

        emergencyMessage = nil
        isUnlockingEmergency = true
        AnalyticsManager.logEvent("emergency_unlock_attempt")
        userProfileManager.useEmergencyUnlock(userId: userId) { result in
            DispatchQueue.main.async {
                isUnlockingEmergency = false
                switch result {
                case .success:
                    let minutes = userProfileManager.cookieValues[CookieType.cookie.rawValue] ?? 30
                    timeAllowanceManager.addMinutes(minutes)
                    emergencyMessage = "Added \(minutes) minutes."
                    AnalyticsManager.logEvent("emergency_unlock_success")
                case .failure(let error):
                    emergencyMessage = error.localizedDescription
                    AnalyticsManager.logEvent("emergency_unlock_failed")
                }
            }
        }
    }

    func syncCookieMinutes() {
        guard !isEditingCookieValue, !isSavingCookieValue else { return }
        cookieMinutes = Double(currentCookieMinutes)
    }

    func saveCookieValue() {
        guard timeAllowanceManager.isUnlockActive else { return }
        guard let userId = authViewModel.user?.uid else {
            activeAlertMessage = "You must be signed in to update cookie value."
            return
        }

        isSavingCookieValue = true
        let minutes = cookieMinutesValue
        userProfileManager.updateCookieValues(userId: userId, values: [
            CookieType.cookie.rawValue: minutes
        ]) { result in
            DispatchQueue.main.async {
                isSavingCookieValue = false
                switch result {
                case .success:
                    AnalyticsManager.logEvent("cookie_value_updated", parameters: [
                        "minutes": minutes
                    ])
                case .failure(let error):
                    activeAlertMessage = error.localizedDescription
                    AnalyticsManager.logEvent("cookie_value_update_failed")
                }
            }
        }
    }

    func openWebLink(_ page: SettingsWebPage) {
        guard let url = webURL(for: page) else {
            activeAlertMessage = "Website link is unavailable."
            return
        }
        activeSafariLink = SafariLink(url: url)
    }

    func webURL(for page: SettingsWebPage) -> URL? {
        let base = websiteBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/#\(page.path)")
    }

    func deleteAccount() {
        guard let userId = authViewModel.user?.uid else {
            return
        }

        isDeletingAccount = true
        AnalyticsManager.logEvent("delete_account_started")
        userProfileManager.deleteUserData(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    authViewModel.deleteAccount { deleteResult in
                        DispatchQueue.main.async {
                            isDeletingAccount = false
                            if case .failure(let error) = deleteResult {
                                activeAlertMessage = error.localizedDescription
                                AnalyticsManager.logEvent("delete_account_failed")
                            }
                        }
                    }
                case .failure(let error):
                    isDeletingAccount = false
                    activeAlertMessage = error.localizedDescription
                    AnalyticsManager.logEvent("delete_account_failed")
                }
            }
        }
    }
}

private enum SettingsWebPage {
    case whyCookies
    case privacy
    case troubleshooting
    case help

    var title: String {
        switch self {
        case .whyCookies:
            return "Why Cookies?"
        case .privacy:
            return "Privacy Policy"
        case .troubleshooting:
            return "Troubleshooting"
        case .help:
            return "Get Help"
        }
    }

    var subtitle: String {
        switch self {
        case .whyCookies:
            return "Why the physical cookie changes your habits."
        case .privacy:
            return "How we handle data and privacy."
        case .troubleshooting:
            return "Fix common issues with scanning and setup."
        case .help:
            return "Contact support and FAQs."
        }
    }

    var path: String {
        switch self {
        case .whyCookies:
            return "/why"
        case .privacy:
            return "/privacy"
        case .troubleshooting:
            return "/troubleshooting"
        case .help:
            return "/help"
        }
    }
}

private struct SafariLink: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsRow: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(Color("CookiesTextPrimary"))
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("CookiesTextSecondary").opacity(0.6))
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel())
            .environmentObject(ScreenTimeManager())
            .environmentObject(TimeAllowanceManager())
            .environmentObject(UserProfileManager())
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
