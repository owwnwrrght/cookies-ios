//
//  CookieService.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum CookieServiceError: LocalizedError {
    case cookieNotFound
    case cookieAlreadyRedeemed
    case cookieAlreadyRegistered
    case packNotFound
    case packAlreadyClaimed
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .cookieNotFound:
            return "This cookie is not registered to your account."
        case .cookieAlreadyRedeemed:
            return "This cookie was already redeemed today. Try again after the daily reset."
        case .cookieAlreadyRegistered:
            return "This cookie has already been registered."
        case .packNotFound:
            return "This pack could not be found."
        case .packAlreadyClaimed:
            return "This pack has already been claimed."
        case .registrationFailed:
            return "Unable to register the cookie."
        }
    }
}

final class CookieService {
    private let database = Firestore.firestore()

    private func logDebug(_ message: String) {
#if DEBUG
        print("[CookieService] \(message)")
#endif
    }

    private func describeValue(_ value: Any?) -> String {
        guard let value else { return "nil" }
        if let timestamp = value as? Timestamp {
            return "Timestamp(\(timestamp.dateValue()))"
        }
        if let reference = value as? DocumentReference {
            return "DocumentReference(\(reference.path))"
        }
        return "\(type(of: value))(\(value))"
    }

    private func describeData(_ data: [String: Any]) -> String {
        let parts = data.map { key, value in
            "\(key)=\(describeValue(value))"
        }.sorted()
        return parts.joined(separator: ", ")
    }

    static func redemptionWindowStart(now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let todayReset = calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: 2
            )
        ) ?? now

        if now >= todayReset {
            return todayReset
        }

        return calendar.date(byAdding: .day, value: -1, to: todayReset) ?? todayReset
    }

    func redeemCookie(
        cookieId: String,
        userId: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        logDebug("Redeem start userId=\(userId) cookieId=\(cookieId)")
        
        let cookieRef = database
            .collection("users")
            .document(userId)
            .collection("cookies")
            .document(cookieId)

        // Timeout Logic
        var didComplete = false
        let completionLock = NSLock()
        
        let safeCompletion: (Result<Int, Error>) -> Void = { result in
            completionLock.lock()
            defer { completionLock.unlock() }
            if !didComplete {
                didComplete = true
                completion(result)
            }
        }
        
        // Fail after 10 seconds if network is hanging
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            safeCompletion(.failure(NSError(
                domain: "CookieService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please check your connection."]
            )))
        }

        database.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(cookieRef)
                guard snapshot.exists else {
                    self.logDebug("Cookie not found for userId=\(userId) cookieId=\(cookieId)")
                    errorPointer?.pointee = CookieServiceError.cookieNotFound as NSError
                    return nil
                }

                let data = snapshot.data() ?? [:]
                let cookieType = data["type"] as? String ?? "unknown"
                self.logDebug("Cookie raw data \(self.describeData(data))")
                let userRef = self.database.collection("users").document(userId)
                let userSnapshot = try transaction.getDocument(userRef)
                let userData = userSnapshot.data() ?? [:]
                let cookieValues = userData["cookieValues"] as? [String: Any] ?? [:]
                let minutesValue = cookieValues[cookieType] as? Int ?? 30
                let lastRedeemedAt = (data["lastRedeemedAt"] as? Timestamp)?.dateValue()
                let now = Date()
        let windowStart = Self.redemptionWindowStart(now: now)
                self.logDebug("Cookie data type=\(cookieType) lastRedeemedAt=\(String(describing: lastRedeemedAt)) windowStart=\(windowStart)")

                if let lastRedeemedAt, lastRedeemedAt >= windowStart {
                    self.logDebug("Redemption blocked: already redeemed in window userId=\(userId) cookieId=\(cookieId)")
                    errorPointer?.pointee = CookieServiceError.cookieAlreadyRedeemed as NSError
                    return nil
                }

                transaction.updateData([
                    "lastRedeemedAt": FieldValue.serverTimestamp(),
                    "lastRedeemedBy": userId
                ], forDocument: cookieRef)

                return [
                    "minutesValue": minutesValue,
                    "cookieType": cookieType
                ]
            } catch {
                self.logDebug("Transaction error userId=\(userId) cookieId=\(cookieId) error=\(error)")
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { result, error in
            if let error {
                let nsError = error as NSError
                self.logDebug("Redeem failed domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
                safeCompletion(.failure(error))
                return
            }
            if let payload = result as? [String: Any],
               let minutesValue = payload["minutesValue"] as? Int {
                let cookieType = payload["cookieType"] as? String ?? "unknown"
                self.logRedemption(
                    cookieId: cookieId,
                    userId: userId,
                    minutesValue: minutesValue,
                    cookieType: cookieType
                )
                safeCompletion(.success(minutesValue))
            } else {
                safeCompletion(.failure(CookieServiceError.registrationFailed))
            }
        }
    }

    private func logRedemption(
        cookieId: String,
        userId: String,
        minutesValue: Int,
        cookieType: String
    ) {
        let redemptionRef = database
            .collection("users")
            .document(userId)
            .collection("redemptions")
            .document()

        var data: [String: Any] = [
            "cookieId": cookieId,
            "minutesValue": minutesValue,
            "cookieType": cookieType,
            "redeemedAt": FieldValue.serverTimestamp()
        ]
        redemptionRef.setData(data)
    }
}
