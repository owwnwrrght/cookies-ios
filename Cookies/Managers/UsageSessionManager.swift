//
//  UsageSessionManager.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import FirebaseFirestore

final class UsageSessionManager {
    private let database = Firestore.firestore()
    private let sessionStartDefaultsKey = "currentSessionStart"
    private var currentUserId: String?
    private var sessionStart: Date? {
        didSet {
            if let sessionStart {
                UserDefaults.standard.set(sessionStart, forKey: sessionStartDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sessionStartDefaultsKey)
            }
        }
    }

    init() {
        sessionStart = UserDefaults.standard.object(forKey: sessionStartDefaultsKey) as? Date
    }

    func updateUser(userId: String?) {
        currentUserId = userId
        if userId == nil {
            sessionStart = nil
        }
    }

    func setUnlockActive(_ isActive: Bool) {
        guard let userId = currentUserId else { return }
        if isActive {
            startSessionIfNeeded(userId: userId)
        } else {
            endSessionIfNeeded(userId: userId)
        }
    }

    private func startSessionIfNeeded(userId: String) {
        if sessionStart != nil { return }
        sessionStart = Date()
        AnalyticsManager.logEvent("usage_session_started")
    }

    private func endSessionIfNeeded(userId: String) {
        guard let start = sessionStart else { return }
        let end = Date()
        let duration = max(0, end.timeIntervalSince(start))
        sessionStart = nil

        let sessionRef = database
            .collection("users")
            .document(userId)
            .collection("sessions")
            .document()

        sessionRef.setData([
            "startAt": Timestamp(date: start),
            "endAt": Timestamp(date: end),
            "durationSeconds": Int(duration)
        ])
        AnalyticsManager.logEvent("usage_session_ended", parameters: [
            "duration_seconds": Int(duration)
        ])
    }
}
