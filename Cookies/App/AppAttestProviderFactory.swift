//
//  AppAttestProviderFactory.swift
//  Cookies
//
//  Created by Owen Wright on 12/19/25.
//

import DeviceCheck
import FirebaseAppCheck
import FirebaseCore

final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            if DCAppAttestService.shared.isSupported,
               let provider = AppAttestProvider(app: app) {
                return provider
            }
        }
        if #available(iOS 11.0, *) {
            return DeviceCheckProvider(app: app)
        }
        return nil
    }
}
