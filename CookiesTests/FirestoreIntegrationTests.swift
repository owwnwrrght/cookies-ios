//
//  FirestoreIntegrationTests.swift
//  CookiesTests
//
//  Created by Owen Wright on 12/19/25.
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class FirestoreIntegrationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        configureEmulatorsIfNeeded()
    }

    private static func configureEmulatorsIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        guard env["USE_FIREBASE_EMULATORS"] == "1" else { return }

        if let authHost = env["FIREBASE_AUTH_EMULATOR_HOST"],
           let (host, port) = hostAndPort(authHost) {
            Auth.auth().useEmulator(withHost: host, port: port)
        }

        if let firestoreHost = env["FIRESTORE_EMULATOR_HOST"],
           let (host, port) = hostAndPort(firestoreHost) {
            Firestore.firestore().useEmulator(withHost: host, port: port)
        }
    }

    private static func hostAndPort(_ value: String) -> (String, Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        return (String(parts[0]), port)
    }

    func testAnonymousUserCanWriteOwnDocument() {
        let signInExpectation = expectation(description: "sign in")
        Auth.auth().signInAnonymously { result, error in
            XCTAssertNil(error)
            guard let userId = result?.user.uid else {
                XCTFail("Missing user ID")
                signInExpectation.fulfill()
                return
            }

            let docRef = Firestore.firestore().collection("users").document(userId)
            docRef.setData(["onboardingComplete": false]) { error in
                XCTAssertNil(error)
                docRef.getDocument { snapshot, error in
                    XCTAssertNil(error)
                    XCTAssertEqual(snapshot?.data()?["onboardingComplete"] as? Bool, false)
                    signInExpectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 10)
    }
}
