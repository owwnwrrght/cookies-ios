//
//  InsightsViewModel.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import Combine
import FirebaseFirestore

struct DailyInsights: Identifiable {
    let id: String
    let date: Date
    let earnedMinutes: Int
    let usedMinutes: Int
    let redeemedCount: Int
}

final class InsightsViewModel: ObservableObject {
    @Published private(set) var dailyInsights: [DailyInsights] = []
    @Published private(set) var totalEarnedMinutes = 0
    @Published private(set) var totalUsedMinutes = 0
    @Published private(set) var tokenRedemptionCount = 0
    @Published private(set) var hasLoaded = false

    private let database = Firestore.firestore()
    private var redemptionsListener: ListenerRegistration?
    private var sessionsListener: ListenerRegistration?
    private let sessionStartDefaultsKey = "currentSessionStart"

    deinit {
        stopListening()
    }

    func startListening(userId: String) {
        stopListening()
        hasLoaded = false

        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: startOfDay(for: Date())) ?? Date()
        let weekStartTimestamp = Timestamp(date: weekStart)

        redemptionsListener = database
            .collection("users")
            .document(userId)
            .collection("redemptions")
            .whereField("redeemedAt", isGreaterThanOrEqualTo: weekStartTimestamp)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.rebuildInsights(redemptionDocs: snapshot?.documents, sessionDocs: nil)
            }

        sessionsListener = database
            .collection("users")
            .document(userId)
            .collection("sessions")
            .whereField("endAt", isGreaterThanOrEqualTo: weekStartTimestamp)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.rebuildInsights(redemptionDocs: nil, sessionDocs: snapshot?.documents)
            }
    }

    func stopListening() {
        redemptionsListener?.remove()
        sessionsListener?.remove()
        redemptionsListener = nil
        sessionsListener = nil
        dailyInsights = []
        totalEarnedMinutes = 0
        totalUsedMinutes = 0
        tokenRedemptionCount = 0
        hasLoaded = false
    }

    private var cachedRedemptionDocs: [QueryDocumentSnapshot] = []
    private var cachedSessionDocs: [QueryDocumentSnapshot] = []

    private func rebuildInsights(
        redemptionDocs: [QueryDocumentSnapshot]?,
        sessionDocs: [QueryDocumentSnapshot]?
    ) {
        if let redemptionDocs {
            cachedRedemptionDocs = redemptionDocs
        }
        if let sessionDocs {
            cachedSessionDocs = sessionDocs
        }

        let calendar = Calendar.current
        let today = startOfDay(for: Date())
        struct DayBucket {
            var earned: Int
            var used: Int
            var redeemedCount: Int
        }

        var dayBuckets: [Date: DayBucket] = [:]
        for offset in (0...6).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                dayBuckets[date] = DayBucket(earned: 0, used: 0, redeemedCount: 0)
            }
        }

        var earnedTotal = 0
        var redemptionCount = 0
        for doc in cachedRedemptionDocs {
            let data = doc.data()
            guard let timestamp = data["redeemedAt"] as? Timestamp else { continue }
            let minutesValue = data["minutesValue"] as? Int ?? 0
            let day = startOfDay(for: timestamp.dateValue())
            if var bucket = dayBuckets[day] {
                bucket.earned += minutesValue
                bucket.redeemedCount += 1
                dayBuckets[day] = bucket
            }
            earnedTotal += minutesValue
            redemptionCount += 1
        }

        var usedTotal = 0
        for doc in cachedSessionDocs {
            let data = doc.data()
            guard let endTimestamp = data["endAt"] as? Timestamp else { continue }
            let durationSeconds = data["durationSeconds"] as? Int ?? 0
            let minutes = Int(Double(durationSeconds) / 60.0)
            let day = startOfDay(for: endTimestamp.dateValue())
            if var bucket = dayBuckets[day] {
                bucket.used += minutes
                dayBuckets[day] = bucket
            }
            usedTotal += minutes
        }

        let now = Date()
        if let activeStart = UserDefaults.standard.object(forKey: sessionStartDefaultsKey) as? Date {
            let todayStart = startOfDay(for: now)
            let activeStartForToday = max(activeStart, todayStart)
            let activeSeconds = max(0, now.timeIntervalSince(activeStartForToday))
            let activeMinutes = Int(activeSeconds / 60.0)
            if activeMinutes > 0, var bucket = dayBuckets[todayStart] {
                bucket.used += activeMinutes
                dayBuckets[todayStart] = bucket
                usedTotal += activeMinutes
            }
        }

        let insights = dayBuckets.keys.sorted().map { day in
            let bucket = dayBuckets[day] ?? DayBucket(earned: 0, used: 0, redeemedCount: 0)
            let id = DateFormatter.localizedString(from: day, dateStyle: .short, timeStyle: .none)
            return DailyInsights(
                id: id,
                date: day,
                earnedMinutes: bucket.earned,
                usedMinutes: bucket.used,
                redeemedCount: bucket.redeemedCount
            )
        }

        DispatchQueue.main.async {
            self.dailyInsights = insights
            self.totalEarnedMinutes = earnedTotal
            self.totalUsedMinutes = usedTotal
            self.tokenRedemptionCount = redemptionCount
            self.hasLoaded = true
        }
    }

    func refreshActiveUsageIfNeeded() {
        guard hasLoaded else { return }
        guard UserDefaults.standard.object(forKey: sessionStartDefaultsKey) as? Date != nil else { return }
        rebuildInsights(redemptionDocs: nil, sessionDocs: nil)
    }

    private func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
