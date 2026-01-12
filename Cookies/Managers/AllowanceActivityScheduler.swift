//
//  AllowanceActivityScheduler.swift
//  Cookies
//
//  Created by Owen Wright on 12/19/25.
//

import DeviceActivity
import Foundation

enum AllowanceActivityScheduler {
    static let activityName = DeviceActivityName("allowance")
    private static let minimumIntervalSeconds: TimeInterval = 15 * 60

    static func updateSchedule(endDate: Date?) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()

        guard let endDate, endDate > Date() else { return }

        let now = Date()
        let scheduleEnd: Date
        let warningTime: DateComponents?

        if endDate.timeIntervalSince(now) < minimumIntervalSeconds {
            scheduleEnd = now.addingTimeInterval(minimumIntervalSeconds)
            let warningInterval = scheduleEnd.timeIntervalSince(endDate)
            warningTime = warningComponents(for: warningInterval)
        } else {
            scheduleEnd = endDate
            warningTime = nil
        }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents(in: TimeZone.current, from: now)
        let endComponents = calendar.dateComponents(in: TimeZone.current, from: scheduleEnd)
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false,
            warningTime: warningTime
        )

        do {
            try center.startMonitoring(activityName, during: schedule)
        } catch {
#if DEBUG
            print("[AllowanceActivityScheduler] Failed to start monitoring: \(error)")
#endif
        }
    }

    private static func warningComponents(for interval: TimeInterval) -> DateComponents {
        let totalSeconds = max(1, Int(ceil(interval)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        var components = DateComponents()
        components.hour = hours
        components.minute = minutes
        components.second = seconds
        return components
    }
}
