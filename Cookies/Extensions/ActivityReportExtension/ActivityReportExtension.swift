import SwiftUI
import _DeviceActivity_SwiftUI

@main
struct ActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        CookiesReportScene(context: .daily) { data in
            await ActivityReportConfiguration.build(
                from: data,
                title: "Today",
                subtitle: "So far"
            )
        } content: { configuration in
            ActivityReportView(configuration: configuration)
        }

        CookiesReportScene(context: .weekly) { data in
            await ActivityReportConfiguration.build(
                from: data,
                title: "This Week",
                subtitle: "Last 7 days"
            )
        } content: { configuration in
            ActivityReportView(configuration: configuration)
        }
    }
}

private struct CookiesReportScene<Configuration, Content: View>: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let configurationBuilder: (DeviceActivityResults<DeviceActivityData>) async -> Configuration
    let content: (Configuration) -> Content

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Configuration {
        await configurationBuilder(data)
    }
}

extension DeviceActivityReport.Context {
    static let daily = Self("daily")
    static let weekly = Self("weekly")
}
