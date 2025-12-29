//
//  AuthViewModel.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import Combine
import FirebaseAuth

final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCodeSent = false

    private let authFlowKey = "hasCompletedAuthFlow"
    private let verificationKey = "authVerificationID"
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            AnalyticsManager.setUserId(user?.uid)
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    func sendVerificationCode(phoneNumber: String) {
        errorMessage = nil
        isLoading = true

        let formattedNumber = Self.formatPhoneNumber(phoneNumber)
        guard !formattedNumber.isEmpty else {
            isLoading = false
            errorMessage = "Enter a valid phone number."
            return
        }

        AnalyticsManager.logEvent("auth_send_code", parameters: [
            "has_phone": true
        ])
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedNumber, uiDelegate: nil) { [weak self] verificationID, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error {
                    let nsError = error as NSError
                    print("Phone auth error:", nsError, nsError.userInfo)
                    self?.errorMessage = error.localizedDescription
                    AnalyticsManager.logEvent("auth_send_code_failed")
                    return
                }
                guard let verificationID else {
                    self?.errorMessage = "Unable to start verification."
                    AnalyticsManager.logEvent("auth_send_code_failed")
                    return
                }
                UserDefaults.standard.set(verificationID, forKey: self?.verificationKey ?? "authVerificationID")
                self?.isCodeSent = true
                AnalyticsManager.logEvent("auth_send_code_success")
            }
        }
    }

    func verifyCode(_ verificationCode: String) {
        errorMessage = nil
        isLoading = true

        guard let verificationID = UserDefaults.standard.string(forKey: verificationKey) else {
            isLoading = false
            errorMessage = "Start verification again."
            AnalyticsManager.logEvent("auth_verify_failed")
            return
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        AnalyticsManager.logEvent("auth_verify_attempt")
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error {
                    self?.errorMessage = error.localizedDescription
                    AnalyticsManager.logEvent("auth_verify_failed")
                    return
                }
                self?.user = result?.user
                UserDefaults.standard.set(true, forKey: self?.authFlowKey ?? "hasCompletedAuthFlow")
                AnalyticsManager.logEvent("auth_verify_success")
            }
        }
    }

    func signOut() {
        errorMessage = nil
        do {
            try Auth.auth().signOut()
            user = nil
            isCodeSent = false
            UserDefaults.standard.set(false, forKey: authFlowKey)
            AnalyticsManager.logEvent("auth_sign_out")
        } catch {
            errorMessage = error.localizedDescription
            AnalyticsManager.logEvent("auth_sign_out_failed")
        }
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        errorMessage = nil
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "Auth", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "No signed-in user."
            ])))
            AnalyticsManager.logEvent("auth_delete_failed")
            return
        }

        AnalyticsManager.logEvent("auth_delete_attempt")
        currentUser.delete { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    AnalyticsManager.logEvent("auth_delete_failed")
                } else {
                    self?.user = nil
                    self?.isCodeSent = false
                    UserDefaults.standard.set(false, forKey: self?.authFlowKey ?? "hasCompletedAuthFlow")
                    completion(.success(()))
                    AnalyticsManager.logEvent("auth_delete_success")
                }
            }
        }
    }

    static func formatPhoneNumber(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }

        if digits.hasPrefix("1"), digits.count == 11 {
            return "+\(digits)"
        }

        if digits.count == 10 {
            return "+1\(digits)"
        }

        return "+\(digits)"
    }

    func formattedPhoneNumber(from input: String) -> String {
        Self.formatPhoneNumber(input)
    }
}
