import SwiftUI
import DeviceActivity
import _DeviceActivity_SwiftUI

struct ActivityReportConfiguration: Sendable {
    struct AppUsage: Identifiable, Sendable {
        let id: String
        let name: String
        let duration: TimeInterval
    }

    let title: String
    let subtitle: String
    let totalDuration: TimeInterval
    let topApps: [AppUsage]
}

extension ActivityReportConfiguration {
    private struct AppUsageAggregate {
        let name: String
        var duration: TimeInterval
    }

    static func build(
        from data: DeviceActivityResults<DeviceActivityData>,
        title: String,
        subtitle: String
    ) async -> ActivityReportConfiguration {
        var totalDuration: TimeInterval = 0
        var appTotals: [String: AppUsageAggregate] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                totalDuration += segment.totalActivityDuration

                for await category in segment.categories {
                    for await appActivity in category.applications {
                        let app = appActivity.application
                        let name = app.localizedDisplayName ?? app.bundleIdentifier ?? "Unknown App"
                        let key = app.bundleIdentifier ?? name
                        var entry = appTotals[key] ?? AppUsageAggregate(name: name, duration: 0)
                        entry.duration += appActivity.totalActivityDuration
                        appTotals[key] = entry
                    }
                }
            }
        }

        let topApps = appTotals
            .filter { $0.value.duration > 0 }
            .sorted { $0.value.duration > $1.value.duration }
            .prefix(5)
            .map { key, value in
                ActivityReportConfiguration.AppUsage(
                    id: key,
                    name: value.name,
                    duration: value.duration
                )
            }

        return ActivityReportConfiguration(
            title: title,
            subtitle: subtitle,
            totalDuration: totalDuration,
            topApps: topApps
        )
    }
}

struct ActivityReportView: View {
    let configuration: ActivityReportConfiguration

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading]
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.title)
                        .font(.headline)
                    Text(configuration.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatDuration(configuration.totalDuration))
                    .font(.headline)
            }

            if configuration.topApps.isEmpty {
                Text("No app activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Top apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(configuration.topApps) { app in
                        HStack {
                            Text(app.name)
                                .font(.subheadline)
                            Spacer()
                            Text(formatDuration(app.duration))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        Self.durationFormatter.string(from: duration) ?? "0m"
    }
}
