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
    private var didInvalidateSession = false
    private let tokenPrefix = "cookies:"
    private let defaultAlertMessage = "Hold your iPhone near the NFC tag."
    private let successMessage = "Tag scanned."
    private let invalidTagMessage = "This tag is not provisioned for Cookies."

    func beginScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            reportError("NFC is not available on this device.")
            return
        }

        resetSessionState()
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = defaultAlertMessage
        session.begin()
        self.session = session
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        session.alertMessage = defaultAlertMessage
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard !didInvalidateSession else { return }
        guard let message = messages.first,
              let token = extractToken(from: message) else {
            handleFailure(session, message: invalidTagMessage)
            return
        }

        handleSuccess(session, token: token)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard !didInvalidateSession else { return }
        guard let tag = tags.first else {
            handleFailure(session, message: "No NFC tag detected.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                self.handleFailure(session, message: self.userMessage(for: error))
                return
            }

            tag.readNDEF { message, readError in
                if let readError {
                    self.handleFailure(session, message: self.userMessage(for: readError))
                    return
                }

                guard let token = self.extractToken(from: message) else {
                    self.handleFailure(session, message: self.invalidTagMessage)
                    return
                }

                self.handleSuccess(session, token: token)
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        defer { self.session = nil }
        if didReadToken || didInvalidateSession {
            return
        }

        if let nfcError = error as? NFCReaderError {
            if nfcError.code == .readerSessionInvalidationErrorUserCanceled ||
                nfcError.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
                return
            }
            reportError(userMessage(for: nfcError))
            return
        }

        reportError(userMessage(for: error))
    }

    private func extractToken(from message: NFCNDEFMessage?) -> String? {
        guard let records = message?.records, let record = records.first else { return nil }
        let (text, _) = record.wellKnownTypeTextPayload()
        if let text {
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

    private func resetSessionState() {
        didReadToken = false
        didInvalidateSession = false
    }

    private func handleSuccess(_ session: NFCNDEFReaderSession, token: String) {
        invalidateSession(session, message: successMessage, didRead: true)
        DispatchQueue.main.async { [weak self] in
            self?.onTokenRead?(token)
        }
    }

    private func handleFailure(_ session: NFCNDEFReaderSession, message: String) {
        invalidateSession(session, message: message, didRead: false)
        reportError(message)
    }

    private func invalidateSession(_ session: NFCNDEFReaderSession, message: String, didRead: Bool) {
        guard !didInvalidateSession else { return }
        didInvalidateSession = true
        didReadToken = didRead
        session.alertMessage = message
        session.invalidate()
        self.session = nil
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }

    private func userMessage(for error: Error) -> String {
        guard let nfcError = error as? NFCReaderError else {
            return "Failed to read NFC tag. Please try again."
        }

        switch nfcError.code {
        case .readerSessionInvalidationErrorSessionTimeout:
            return "NFC session timed out. Hold your iPhone near the tag and try again."
        case .readerSessionInvalidationErrorSystemIsBusy:
            return "Another NFC session is in progress. Try again in a moment."
        case .readerErrorUnsupportedFeature:
            return "This device does not support scanning this type of tag."
        default:
            return "Failed to read NFC tag. Please try again."
        }
    }
}
