//
//  ShieldConfigurationExtension.swift
//  QuarterShieldConfiguration
//
//  Created by Owen Wright on 12/19/25.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    nonisolated override init() {
        super.init()
    }

    nonisolated override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(named: "CookiesBackground") ?? UIColor.systemBackground,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "Blocked by Cookies",
                color: UIColor(named: "CookiesTextPrimary") ?? UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This app is currently locked.",
                color: UIColor(named: "CookiesTextSecondary") ?? UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor(named: "CookiesButtonText") ?? UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(named: "CookiesButtonFill") ?? UIColor.systemBlue
        )
    }

    nonisolated override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(named: "CookiesBackground") ?? UIColor.systemBackground,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "Blocked by Cookies",
                color: UIColor(named: "CookiesTextPrimary") ?? UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This category is currently locked.",
                color: UIColor(named: "CookiesTextSecondary") ?? UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor(named: "CookiesButtonText") ?? UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(named: "CookiesButtonFill") ?? UIColor.systemBlue
        )
    }

    nonisolated override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(named: "CookiesBackground") ?? UIColor.systemBackground,
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "Blocked by Cookies",
                color: UIColor(named: "CookiesTextPrimary") ?? UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This website is currently locked.",
                color: UIColor(named: "CookiesTextSecondary") ?? UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor(named: "CookiesButtonText") ?? UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(named: "CookiesButtonFill") ?? UIColor.systemBlue
        )
    }
}
