//
//  MainTabView.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import SwiftUI
import Combine
import FirebaseAuth

struct MainTabView: View {
    var body: some View {
        HomeView()
    }
}

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CookiesDashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            ActivityView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Activity")
                }
                .tag(1)

                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .tag(2)
            }
            .accentColor(Color("CookiesAccent"))
        }
    }

struct CookiesDashboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var timeAllowanceManager: TimeAllowanceManager
    @StateObject private var nfcScanner = NFCScanner()
    @State private var isScanning = false
    @State private var isLocked = true
    @State private var isRedeeming = false
    @State private var warningMessage: String?
    @State private var warningColor: Color = .yellow
    @State private var warningResetTask: Task<Void, Never>?

    private let cookieService = CookieService()

    var body: some View {
        ZStack {
                Color("CookiesBackground")
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    Spacer()
                    
                    if isRedeeming {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Verifying Cookie...")
                                .font(.headline)
                                .foregroundColor(Color("CookiesTextSecondary"))
                        }
                    } else {
                        Button(action: {
                            withAnimation(.spring()) {
                                startScan()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color("CookiesSurface"))
                                    .frame(width: 240, height: 240)
                                    .shadow(color: Color("Lead").opacity(0.12), radius: 10, x: 0, y: 5)
        
                                VStack(spacing: 10) {
                                    Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(isLocked ? Color("CookiesTextPrimary") : Color("CookiesTextSecondary"))
        
                                    Text(isLocked ? "Eat Cookie" : formattedTime(timeAllowanceManager.remainingSeconds))
                                        .font(.headline)
                                        .tracking(2)
                                        .foregroundColor(isLocked ? Color("CookiesTextPrimary") : Color("CookiesTextSecondary"))
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isScanning)
                    }

                if let warningMessage {
                    Text(warningMessage)
                        .font(.subheadline)
                        .foregroundColor(warningColor)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                }

                    Spacer()

                    Spacer().frame(height: 20)

                }
            }
        .onAppear {
            isLocked = !timeAllowanceManager.isUnlockActive
            timeAllowanceManager.refresh()
            nfcScanner.onTokenRead = { tokenId in
                redeemCookie(tokenId)
            }
            nfcScanner.onError = { _ in
                isScanning = false
            }
            AnalyticsManager.logScreen("Home", className: "CookiesDashboardView")
        }
        .onChange(of: timeAllowanceManager.isUnlockActive) { _, newValue in
            withAnimation(.spring()) {
                isLocked = !newValue
            }
        }
    }
}

private extension CookiesDashboardView {
    func formattedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startScan() {
        guard !isScanning, !isRedeeming else { return }
        warningMessage = nil
        isScanning = true
        AnalyticsManager.logEvent("cookie_scan_started")
        nfcScanner.beginScanning()
    }

    func redeemCookie(_ cookieId: String) {
        guard let userId = authViewModel.user?.uid else {
            isScanning = false
            return
        }
#if DEBUG
        print("[CookiesDashboardView] Redeem attempt userId=\(userId) cookieId=\(cookieId)")
#endif
        // Immediately show redeeming state, hide scanner
        isScanning = false
        isRedeeming = true

        cookieService.redeemCookie(cookieId: cookieId, userId: userId) { result in
            DispatchQueue.main.async {
                isRedeeming = false
                switch result {
                case .success(let minutesValue):
                    timeAllowanceManager.addMinutes(minutesValue)
                    AnalyticsManager.logEvent("cookie_redeem_success", parameters: [
                        "minutes": minutesValue
                    ])
                case .failure(let error):
                    if let serviceError = error as? CookieServiceError {
                        switch serviceError {
                        case .cookieAlreadyRedeemed:
                            showWarning("This tag was already scanned today.", color: .yellow)
                            AnalyticsManager.logEvent("cookie_redeem_failed", parameters: [
                                "reason": "already_redeemed"
                            ])
                        case .cookieNotFound:
                            showWarning("This tag is not recognized.", color: .red)
                            AnalyticsManager.logEvent("cookie_redeem_failed", parameters: [
                                "reason": "not_found"
                            ])
                        default:
                            showWarning(error.localizedDescription, color: .red)
                            AnalyticsManager.logEvent("cookie_redeem_failed", parameters: [
                                "reason": "unknown"
                            ])
                        }
                    } else {
                        showWarning(error.localizedDescription, color: .red)
                        AnalyticsManager.logEvent("cookie_redeem_failed", parameters: [
                            "reason": "unknown"
                        ])
                    }
                }
            }
        }
    }

    func showWarning(_ message: String, color: Color) {
        warningResetTask?.cancel()
        warningMessage = message
        warningColor = color
        warningResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            warningMessage = nil
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = InsightsViewModel()
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    fileprivate struct DayActivity: Identifiable {
        let id: String
        let label: String
        let cookiesScanned: Int
        let earnedMinutes: Int
        let usedMinutes: Int
        let remainingMinutes: Int
        let isToday: Bool
    }

    fileprivate struct SummaryMetrics {
        let earnedMinutes: Int
        let usedMinutes: Int
        let remainingMinutes: Int
        let cookiesScanned: Int
    }

    private var dayActivities: [DayActivity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.dailyInsights.reversed().map { insight in
            let label = labelForDay(insight.date, today: today)
            let earned = max(0, insight.earnedMinutes)
            let used = max(0, insight.usedMinutes)
            let remaining = max(0, earned - used)
            return DayActivity(
                id: insight.id,
                label: label,
                cookiesScanned: insight.redeemedCount,
                earnedMinutes: earned,
                usedMinutes: used,
                remainingMinutes: remaining,
                isToday: calendar.isDate(insight.date, inSameDayAs: today)
            )
        }
    }

    private var todaySummary: SummaryMetrics? {
        let calendar = Calendar.current
        guard let today = viewModel.dailyInsights.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) else {
            return nil
        }
        let earned = max(0, today.earnedMinutes)
        let used = max(0, today.usedMinutes)
        let remaining = max(0, earned - used)
        return SummaryMetrics(
            earnedMinutes: earned,
            usedMinutes: used,
            remainingMinutes: remaining,
            cookiesScanned: today.redeemedCount
        )
    }

    private var weekSummary: SummaryMetrics {
        let earned = max(0, viewModel.totalEarnedMinutes)
        let used = max(0, viewModel.totalUsedMinutes)
        let remaining = max(0, earned - used)
        return SummaryMetrics(
            earnedMinutes: earned,
            usedMinutes: used,
            remainingMinutes: remaining,
            cookiesScanned: viewModel.tokenRedemptionCount
        )
    }

    var body: some View {
        ZStack {
            Color("CookiesBackground")
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activity")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("CookiesTextPrimary"))
                        Text("Last 7 days")
                            .font(.subheadline)
                            .foregroundColor(Color("CookiesTextSecondary"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                    if !viewModel.hasLoaded {
                        ProgressView("Loading activity...")
                            .padding(.top, 20)
                    } else {
                        if let todaySummary {
                            ActivitySummaryCard(
                                title: "Today",
                                subtitle: "So far",
                                metrics: todaySummary
                            )
                        }

                        ActivitySummaryCard(
                            title: "This Week",
                            subtitle: "Last 7 days",
                            metrics: weekSummary
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily breakdown")
                                .font(.headline)
                                .foregroundColor(Color("CookiesTextPrimary"))

                            ForEach(dayActivities, id: \.id) { entry in
                                ActivityRow(activity: entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 18)
            }
        }
        .onAppear {
            if let userId = authViewModel.user?.uid {
                viewModel.startListening(userId: userId)
            }
            AnalyticsManager.logScreen("Activity", className: "ActivityView")
        }
        .onChange(of: authViewModel.user?.uid) { _, newValue in
            if let userId = newValue {
                viewModel.startListening(userId: userId)
            } else {
                viewModel.stopListening()
            }
        }
        .onReceive(refreshTimer) { _ in
            viewModel.refreshActiveUsageIfNeeded()
        }
    }
}

private extension ActivityView {
    func labelForDay(_ date: Date, today: Date) -> String {
        if Calendar.current.isDate(date, inSameDayAs: today) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

}

private struct ActivitySummaryCard: View {
    let title: String
    let subtitle: String
    let metrics: ActivityView.SummaryMetrics

    private var progress: Double {
        let earned = Double(metrics.earnedMinutes)
        guard earned > 0 else { return 0 }
        return min(1, Double(metrics.usedMinutes) / earned)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color("CookiesTextPrimary"))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color("CookiesTextSecondary"))
                }
                Spacer()
                Text("\(metrics.cookiesScanned) cookies")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("CookiesTextPrimary"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color("CookiesSurfaceAlt"))
                    .clipShape(Capsule())
            }

            ProgressBar(progress: progress)

            HStack(spacing: 12) {
                MetricTile(title: "Earned", value: formatMinutes(metrics.earnedMinutes))
                MetricTile(title: "Used", value: formatMinutes(metrics.usedMinutes))
                MetricTile(title: "Left", value: formatMinutes(metrics.remainingMinutes))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color("CookiesSurface"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color("Lead").opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private struct ActivityRow: View {
    let activity: ActivityView.DayActivity

    private var progress: Double {
        let earned = Double(activity.earnedMinutes)
        guard earned > 0 else { return 0 }
        return min(1, Double(activity.usedMinutes) / earned)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(activity.label)
                    .font(.headline)
                    .foregroundColor(Color("CookiesTextPrimary"))
                Spacer()
                Text("\(activity.cookiesScanned) cookies")
                    .font(.subheadline)
                    .foregroundColor(Color("CookiesTextSecondary"))
            }

            ProgressBar(progress: progress)

            HStack(spacing: 12) {
                MetricTile(title: "Earned", value: formatMinutes(activity.earnedMinutes))
                MetricTile(title: "Used", value: formatMinutes(activity.usedMinutes))
                MetricTile(title: "Left", value: formatMinutes(activity.remainingMinutes))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(activity.isToday ? Color("CookiesSurface") : Color("CookiesSurfaceAlt"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2)
                .tracking(1)
                .foregroundColor(Color("CookiesTextSecondary"))
            Text(value)
                .font(.headline)
                .foregroundColor(Color("CookiesTextPrimary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color("CookiesSurface").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color("CookiesSurfaceAlt"))
                Capsule()
                    .fill(Color("CookiesAccent"))
                    .frame(width: width * clamped)
            }
        }
        .frame(height: 8)
    }
}

private func formatMinutes(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours > 0 {
        return "\(hours)h \(remainder)m"
    }
    return "\(remainder)m"
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(ScreenTimeManager())
        .environmentObject(TimeAllowanceManager())
        .environmentObject(UserProfileManager())
}
