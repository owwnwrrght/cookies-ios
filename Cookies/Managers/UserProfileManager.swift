//
//  UserProfileManager.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import Combine
import FirebaseFirestore

final class UserProfileManager: ObservableObject {
    @Published private(set) var hasCompletedOnboarding = false
    @Published private(set) var lastEmergencyUnlockAt: Date?
    @Published private(set) var hasLoadedProfile = false
    @Published private(set) var cookieValues: [String: Int] = [
        CookieType.cookie.rawValue: 30
    ]
    private let defaultCookieValues: [String: Int] = [
        CookieType.cookie.rawValue: 30
    ]

    private let database = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentUserId: String?

    deinit {
        stopListening()
    }

    func startListening(userId: String) {
        guard currentUserId != userId else { return }
        stopListening()
        currentUserId = userId
        hasLoadedProfile = false
        cookieValues = defaultCookieValues
        listener = database.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, _ in
            let data = snapshot?.data() ?? [:]
            let completed = data["onboardingComplete"] as? Bool ?? false
            let lastUnlock = (data["lastEmergencyUnlockAt"] as? Timestamp)?.dateValue()
            let values = data["cookieValues"] as? [String: Int]
            DispatchQueue.main.async {
                self?.hasCompletedOnboarding = completed
                self?.lastEmergencyUnlockAt = lastUnlock
                if let values {
                    self?.cookieValues = values
                }
                self?.hasLoadedProfile = true
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        currentUserId = nil
        hasCompletedOnboarding = false
        lastEmergencyUnlockAt = nil
        hasLoadedProfile = false
        cookieValues = defaultCookieValues
    }

    func markOnboardingComplete(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = database.collection("users").document(userId)
        userRef.setData([
            "onboardingComplete": true,
            "onboardedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func updateCookieValues(userId: String, values: [String: Int], completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = database.collection("users").document(userId)
        userRef.setData([
            "cookieValues": values
        ], merge: true) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func updateTimezoneOffsetMinutes(userId: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let userRef = database.collection("users").document(userId)
        userRef.setData([
            "timezoneOffsetMinutes": offsetMinutes,
            "timezoneUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            guard let completion else { return }
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    var nextEmergencyUnlockDate: Date? {
        guard let lastEmergencyUnlockAt else { return nil }
        return Calendar.current.date(byAdding: .day, value: 7, to: lastEmergencyUnlockAt)
    }

    var canUseEmergencyUnlock: Bool {
        guard let next = nextEmergencyUnlockDate else { return true }
        return Date() >= next
    }

    func useEmergencyUnlock(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = database.collection("users").document(userId)
        database.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(userRef)
                let data = snapshot.data() ?? [:]
                let lastUnlock = (data["lastEmergencyUnlockAt"] as? Timestamp)?.dateValue()
                let now = Date()
                if let lastUnlock,
                   let next = Calendar.current.date(byAdding: .day, value: 7, to: lastUnlock),
                   now < next {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    let message = "Emergency unlock available on \(formatter.string(from: next))."
                    errorPointer?.pointee = NSError(domain: "EmergencyUnlock", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: message
                    ])
                    return nil
                }

                transaction.setData([
                    "lastEmergencyUnlockAt": FieldValue.serverTimestamp()
                ], forDocument: userRef, merge: true)
                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { _, error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func deleteUserData(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = database.collection("users").document(userId)
        let cookiesRef = userRef.collection("cookies")
        let redemptionsRef = userRef.collection("redemptions")
        let sessionsRef = userRef.collection("sessions")

        let dispatchGroup = DispatchGroup()
        var batchError: Error?

        func deleteCollection(_ ref: CollectionReference) {
            dispatchGroup.enter()
            ref.getDocuments { snapshot, error in
                if let error {
                    batchError = error
                    dispatchGroup.leave()
                    return
                }
                let batch = self.database.batch()
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                batch.commit { error in
                    if let error {
                        batchError = error
                    }
                    dispatchGroup.leave()
                }
            }
        }

        deleteCollection(cookiesRef)
        deleteCollection(redemptionsRef)
        deleteCollection(sessionsRef)

        dispatchGroup.notify(queue: .main) {
            if let batchError {
                completion(.failure(batchError))
                return
            }
            userRef.delete { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}
