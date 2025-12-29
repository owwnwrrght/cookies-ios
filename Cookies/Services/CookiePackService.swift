//
//  CookiePackService.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Models

enum CookieType: String, CaseIterable, Identifiable, Codable {
    case cookie = "cookie"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cookie: return "Cookie"
        }
    }
}

// MARK: - Errors

enum CookiePackError: LocalizedError {
    case packNotFound
    case packAlreadyClaimed
    case cookieAlreadyRegistered
    case invalidPack
    case unknownError

    var errorDescription: String? {
        switch self {
        case .packNotFound:
            return "This cookie is not linked to a valid pack."
        case .packAlreadyClaimed:
            return "This pack has already been claimed."
        case .cookieAlreadyRegistered:
            return "One of these cookies is already registered."
        case .invalidPack:
            return "This pack is invalid or missing cookies."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}

// MARK: - Service

final class CookiePackService {
    private let database = Firestore.firestore()

    private struct PackClaimContext {
        let packId: String
        let cookies: [(id: String, type: CookieType)]
    }

    private func parsePackCookies(_ data: [String: Any], cookieId: String) throws -> [(id: String, type: CookieType)] {
        guard let rawCookies = data["cookies"] as? [[String: Any]], !rawCookies.isEmpty else {
            throw CookiePackError.invalidPack
        }

        var parsedCookies: [(id: String, type: CookieType)] = []
        for item in rawCookies {
            guard let id = item["id"] as? String,
                  let typeStr = item["type"] as? String,
                  let type = CookieType(rawValue: typeStr) else {
                throw CookiePackError.invalidPack
            }
            parsedCookies.append((id: id, type: type))
        }

        let uniqueIds = Set(parsedCookies.map { $0.id })
        guard
            uniqueIds.count == parsedCookies.count,
            parsedCookies.count == 4,
            let firstType = parsedCookies.first?.type,
            parsedCookies.allSatisfy({ $0.type == firstType }),
            parsedCookies.contains(where: { $0.id == cookieId })
        else {
            throw CookiePackError.invalidPack
        }

        return parsedCookies
    }

    /// Creates a new pack of 4 cookies in Firestore.
    /// - Parameters:
    ///   - cookies: A list of tuples containing the Cookie ID and Type.
    func createPack(cookies: [(id: String, type: CookieType)]) async throws {
        // 1. Validation Logic
        let uniqueIds = Set(cookies.map { $0.id })
        guard
            uniqueIds.count == cookies.count,
            cookies.count == 4,
            let firstType = cookies.first?.type,
            cookies.allSatisfy({ $0.type == firstType })
        else {
            throw CookiePackError.invalidPack
        }

        let packRef = database.collection("packs").document()
        let registry = database.collection("cookieRegistry")

        // 2. Transaction
        try await database.runTransaction { transaction, errorPointer in
            
            // Check if any cookie ID is already registered
            for cookie in cookies {
                let cookieRef = registry.document(cookie.id)
                do {
                    let snapshot = try transaction.getDocument(cookieRef)
                    if snapshot.exists {
                        throw CookiePackError.cookieAlreadyRegistered
                    }
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }

            // Prepare Payload
            let cookiePayload = cookies.map { ["id": $0.id, "type": $0.type.rawValue] }
            
            // Write Pack Data
            transaction.setData([
                "status": "available",
                "createdAt": FieldValue.serverTimestamp(),
                "cookies": cookiePayload,
                "type": firstType.rawValue
            ], forDocument: packRef)

            // Register Individual Cookies
            for cookie in cookies {
                let cookieRef = registry.document(cookie.id)
                transaction.setData([
                    "packId": packRef.documentID,
                    "type": cookie.type.rawValue,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: cookieRef)
            }

            return nil
        }
    }

    /// Claims a pack for a specific user based on a scanned Cookie ID.
    /// - Parameters:
    ///   - cookieId: The ID from the scanned NFC tag.
    ///   - userId: The User ID claiming the pack.
    func claimPack(cookieId: String, userId: String) async throws {
        let registryRef = database.collection("cookieRegistry").document(cookieId)
        let userRef = database.collection("users").document(userId)
        let userCookiesRef = userRef.collection("cookies")

        let context = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let registrySnapshot = try transaction.getDocument(registryRef)
                guard let registryData = registrySnapshot.data(),
                      let packId = registryData["packId"] as? String else {
                    throw CookiePackError.packNotFound
                }

                let packRef = self.database.collection("packs").document(packId)
                let packSnapshot = try transaction.getDocument(packRef)
                guard packSnapshot.exists, let data = packSnapshot.data() else {
                    throw CookiePackError.packNotFound
                }

                let parsedCookies = try self.parsePackCookies(data, cookieId: cookieId)
                let status = data["status"] as? String
                let claimedBy = data["claimedBy"] as? String

                if status == "claimed" {
                    guard claimedBy == userId else {
                        throw CookiePackError.packAlreadyClaimed
                    }
                    return PackClaimContext(packId: packRef.documentID, cookies: parsedCookies)
                }

                guard status == nil || status == "available" else {
                    throw CookiePackError.invalidPack
                }

                for cookie in parsedCookies {
                    let cookieRef = userCookiesRef.document(cookie.id)
                    let snapshot = try transaction.getDocument(cookieRef)
                    if snapshot.exists {
                        throw CookiePackError.cookieAlreadyRegistered
                    }
                }

                transaction.updateData([
                    "status": "claimed",
                    "claimedBy": userId,
                    "claimedAt": FieldValue.serverTimestamp(),
                    "claimCookieId": cookieId
                ], forDocument: packRef)

                return PackClaimContext(packId: packRef.documentID, cookies: parsedCookies)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }

        guard let claimContext = context as? PackClaimContext else {
            throw CookiePackError.unknownError
        }

        try await database.runTransaction { transaction, errorPointer in
            do {
                var snapshots: [String: DocumentSnapshot] = [:]
                for cookie in claimContext.cookies {
                    let cookieRef = userCookiesRef.document(cookie.id)
                    let snapshot = try transaction.getDocument(cookieRef)
                    snapshots[cookie.id] = snapshot
                }

                for cookie in claimContext.cookies {
                    guard let snapshot = snapshots[cookie.id] else { continue }
                    if snapshot.exists {
                        let data = snapshot.data() ?? [:]
                        let existingPackId = data["packId"] as? String
                        let existingType = data["type"] as? String
                        if existingPackId != claimContext.packId || existingType != cookie.type.rawValue {
                            throw CookiePackError.cookieAlreadyRegistered
                        }
                        continue
                    }

                    let cookieRef = userCookiesRef.document(cookie.id)
                    transaction.setData([
                        "type": cookie.type.rawValue,
                        "packId": claimContext.packId,
                        "assignedAt": FieldValue.serverTimestamp()
                    ], forDocument: cookieRef)
                }

                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
    }
}
