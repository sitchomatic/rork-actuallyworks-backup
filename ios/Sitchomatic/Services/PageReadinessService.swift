import Foundation
import WebKit

@MainActor
class PageReadinessService {
    static let shared = PageReadinessService()

    private let logger = DebugLogger.shared
    private let buttonRecovery = SmartButtonRecoveryService.shared

    static let guaranteeBufferSeconds: Double = 1.0

    struct ReadinessResult {
        let ready: Bool
        let durationMs: Int
        let reason: String
        let jsSettled: Bool
        let formReady: Bool
        let buttonReady: Bool
    }

    func waitForFullPageReadiness(
        executeJS: @escaping (String) async -> String?,
        host: String,
        sessionId: String,
        maxTimeoutMs: Int = 30000
    ) async -> ReadinessResult {
        let start = Date()
        let waitMs = min(maxTimeoutMs, 3000)
        try? await Task.sleep(for: .milliseconds(waitMs))
        try? await Task.sleep(for: .seconds(Self.guaranteeBufferSeconds))
        let finalMs = Int(Date().timeIntervalSince(start) * 1000)
        logger.log("PageReadiness: AI Vision pipeline — fixed \(waitMs)ms wait + 1s buffer on \(host)", category: .automation, level: .info, sessionId: sessionId)
        return ReadinessResult(ready: true, durationMs: finalMs, reason: "AI Vision pipeline — fixed wait + 1s buffer", jsSettled: true, formReady: true, buttonReady: true)
    }

    struct ButtonReadyResult {
        let ready: Bool
        let durationMs: Int
        let reason: String
        let recoveredFromFingerprint: Bool
    }

    func waitForButtonReadyForNextAttempt(
        executeJS: @escaping (String) async -> String?,
        originalFingerprint: SmartButtonRecoveryService.ButtonFingerprint?,
        host: String,
        sessionId: String,
        maxTimeoutMs: Int = 25000
    ) async -> ButtonReadyResult {
        let start = Date()
        try? await Task.sleep(for: .seconds(2))
        try? await Task.sleep(for: .seconds(Self.guaranteeBufferSeconds))
        let finalMs = Int(Date().timeIntervalSince(start) * 1000)
        logger.log("PageReadiness: AI Vision pipeline — fixed 2s wait + 1s buffer for button ready on \(host)", category: .automation, level: .info, sessionId: sessionId)
        return ButtonReadyResult(ready: true, durationMs: finalMs, reason: "AI Vision pipeline — fixed 2s + 1s buffer", recoveredFromFingerprint: false)
    }
}
