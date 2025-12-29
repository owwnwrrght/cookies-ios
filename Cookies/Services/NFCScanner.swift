//
//  NFCScanner.swift
//  Quarter
//
//  Created by Owen Wright on 12/19/25.
//

import Foundation
import Combine
import CoreNFC

final class NFCScanner: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    private var session: NFCNDEFReaderSession?
    var onTokenRead: ((String) -> Void)?
    var onError: ((String) -> Void)?
    private var didReadToken = false
    private let tokenPrefix = "cookies:"

    func beginScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            onError?("NFC is not available on this device.")
            return
        }

        didReadToken = false
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session.alertMessage = "Hold your iPhone near the NFC tag."
        session.begin()
        self.session = session
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No NFC tag detected.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "Could not connect to the NFC tag.")
                self?.onError?(error.localizedDescription)
                return
            }

            tag.readNDEF { message, readError in
                if let readError {
                    session.invalidate(errorMessage: "Could not read the NFC tag.")
                    self?.onError?(readError.localizedDescription)
                    return
                }

                guard let token = self?.extractToken(from: message) else {
                    session.invalidate(errorMessage: "Invalid NFC tag.")
                    self?.onError?("This tag is not provisioned for Cookies.")
                    return
                }

                session.alertMessage = "Tag scanned."
                self?.didReadToken = true
                session.invalidate()
                DispatchQueue.main.async {
                    self?.onTokenRead?(token)
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let readerError = error as NSError
        if didReadToken {
            return
        }
        if readerError.domain == NFCReaderError.errorDomain,
           readerError.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
            onError?("Scan cancelled.")
            return
        }
        onError?(error.localizedDescription)
    }

    private func extractToken(from message: NFCNDEFMessage?) -> String? {
        guard let records = message?.records, let record = records.first else { return nil }
        if let (text, _) = record.wellKnownTypeTextPayload() {
            return normalizeToken(text)
        }
        if let payloadString = String(data: record.payload, encoding: .utf8) {
            return normalizeToken(payloadString)
        }
        return nil
    }

    private func normalizeToken(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = trimmed.hasPrefix(tokenPrefix)
            ? String(trimmed.dropFirst(tokenPrefix.count))
            : trimmed
        return token.isEmpty ? nil : token
    }
}
