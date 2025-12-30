//
//  TimeAllowanceManager.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import Combine

final class TimeAllowanceManager: ObservableObject {
    @Published private(set) var remainingSeconds: TimeInterval = 0
    @Published private(set) var isUnlockActive = false
    @Published private(set) var sessionTotalSeconds: TimeInterval = 0
    private let lastUserIdKey = "allowanceLastUserId"
    private let pendingEndDateKey = "allowanceEndDate.pending"
    private var currentUserId: String?
    private var endDateDefaultsKey: String? {
        guard let currentUserId else { return nil }
        return "allowanceEndDate.\(currentUserId)"
    }
    private var endDate: Date? {
        didSet {
            saveEndDate()
            updateRemaining()
        }
    }
    private var timer: Timer?

    init() {
        endDate = nil
        remainingSeconds = 0
        isUnlockActive = false
        sessionTotalSeconds = 0
        restoreCachedEndDate()
        startTimer()
    }

    func addMinutes(_ minutes: Int) {
        let now = Date()
        let additional = TimeInterval(minutes * 60)
        let newEndDate: Date
        if let endDate, endDate > now {
            newEndDate = endDate.addingTimeInterval(additional)
        } else {
            newEndDate = now.addingTimeInterval(additional)
        }
        endDate = newEndDate
        sessionTotalSeconds = max(sessionTotalSeconds, newEndDate.timeIntervalSince(now))
        if currentUserId == nil {
            UserDefaults.standard.set(newEndDate, forKey: pendingEndDateKey)
        }
    }

    func refresh() {
        updateRemaining()
    }

    func setUserId(_ userId: String?) {
        let defaults = UserDefaults.standard
        if userId == nil {
            currentUserId = nil
            endDate = nil
            sessionTotalSeconds = 0
            defaults.removeObject(forKey: lastUserIdKey)
            defaults.removeObject(forKey: pendingEndDateKey)
            return
        }
        guard currentUserId != userId else { return }
        currentUserId = userId
        defaults.set(userId, forKey: lastUserIdKey)
        let saved = defaults.object(forKey: "allowanceEndDate.\(userId)") as? Date
        if let saved {
            endDate = saved
            defaults.removeObject(forKey: pendingEndDateKey)
        } else if let pending = defaults.object(forKey: pendingEndDateKey) as? Date {
            endDate = pending
            defaults.removeObject(forKey: pendingEndDateKey)
        } else {
            endDate = nil
        }
        sessionTotalSeconds = 0
    }

    private func restoreCachedEndDate() {
        let defaults = UserDefaults.standard
        if let lastUserId = defaults.string(forKey: lastUserIdKey) {
            currentUserId = lastUserId
            let saved = defaults.object(forKey: "allowanceEndDate.\(lastUserId)") as? Date
            endDate = saved
            return
        }
        if let pending = defaults.object(forKey: pendingEndDateKey) as? Date {
            endDate = pending
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemaining()
        }
    }

    private func updateRemaining() {
        let now = Date()
        let target = endDate ?? now
        let remaining = max(0, floor(target.timeIntervalSince(now)))
        if remaining != remainingSeconds {
            remainingSeconds = remaining
        }
        let unlockActive = remaining > 0
        if unlockActive != isUnlockActive {
            isUnlockActive = unlockActive
        }
        if remaining > sessionTotalSeconds {
            sessionTotalSeconds = remaining
        }
        if remaining == 0, sessionTotalSeconds != 0 {
            sessionTotalSeconds = 0
        }
    }

    private func saveEndDate() {
        guard let key = endDateDefaultsKey else { return }
        if let endDate {
            UserDefaults.standard.set(endDate, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
