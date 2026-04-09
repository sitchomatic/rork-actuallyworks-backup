import Foundation
import UIKit

@MainActor
final class AIVisionSettlementService {
    static let shared = AIVisionSettlementService()

    private let logger = DebugLogger.shared
    private let aiVision = UnifiedAIVisionService.shared

    struct SettlementResult {
        let settled: Bool
        let outcome: LoginOutcome?
        let durationMs: Int
        let confidence: Int
        let reasoning: String
    }

    func waitForSettlement(
        captureScreenshot: @escaping () async -> UIImage?,
        context: VisionContext,
        maxTimeoutMs: Int = 15000,
        sessionId: String = ""
    ) async -> SettlementResult {
        let start = Date()
        let intervals = [500, 1500, 3000, 5000, 8000, 12000]

        for intervalMs in intervals {
            guard !Task.isCancelled else { break }
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            if elapsed >= maxTimeoutMs { break }

            let waitMs = max(0, intervalMs - elapsed)
            if waitMs > 0 {
                try? await Task.sleep(for: .milliseconds(waitMs))
            }

            guard let screenshot = await captureScreenshot() else { continue }

            let settlementContext = VisionContext(
                site: context.site,
                phase: .settlement,
                currentURL: context.currentURL,
                attemptNumber: context.attemptNumber
            )
            let result = await aiVision.analyzeScreenshot(screenshot, context: settlementContext)

            if result.isPageBlank {
                logger.log("AISettlement: blank page at \(intervalMs)ms — continuing", category: .automation, level: .warning, sessionId: sessionId)
                continue
            }

            if result.isPageSettled {
                let finalMs = Int(Date().timeIntervalSince(start) * 1000)
                logger.log("AISettlement: SETTLED in \(finalMs)ms — \(result.outcome) (\(result.confidence)%) \(result.reasoning)", category: .automation, level: .success, sessionId: sessionId)
                return SettlementResult(
                    settled: true,
                    outcome: result.outcome,
                    durationMs: finalMs,
                    confidence: result.confidence,
                    reasoning: result.reasoning
                )
            }

            logger.log("AISettlement: not settled at \(intervalMs)ms — \(result.reasoning)", category: .automation, level: .trace, sessionId: sessionId)
        }

        let finalMs = Int(Date().timeIntervalSince(start) * 1000)

        if let screenshot = await captureScreenshot() {
            let loginContext = VisionContext(
                site: context.site,
                phase: .loginOutcome,
                currentURL: context.currentURL,
                attemptNumber: context.attemptNumber
            )
            let finalResult = await aiVision.analyzeScreenshot(screenshot, context: loginContext)
            logger.log("AISettlement: timeout after \(finalMs)ms — final analysis: \(finalResult.outcome) (\(finalResult.confidence)%)", category: .automation, level: .warning, sessionId: sessionId)
            return SettlementResult(
                settled: true,
                outcome: finalResult.outcome,
                durationMs: finalMs,
                confidence: finalResult.confidence,
                reasoning: "Timeout — final screenshot analysis: \(finalResult.reasoning)"
            )
        }

        return SettlementResult(settled: true, outcome: .noAcc, durationMs: finalMs, confidence: 30, reasoning: "Timeout — no screenshot available")
    }

    func quickSettlementCheck(
        captureScreenshot: @escaping () async -> UIImage?,
        context: VisionContext,
        sessionId: String = ""
    ) async -> SettlementResult {
        try? await Task.sleep(for: .seconds(2))

        guard let screenshot = await captureScreenshot() else {
            return SettlementResult(settled: true, outcome: .connectionFailure, durationMs: 2000, confidence: 50, reasoning: "No screenshot available")
        }

        let result = await aiVision.analyzeScreenshot(screenshot, context: context)
        return SettlementResult(
            settled: result.isPageSettled,
            outcome: result.outcome,
            durationMs: 2000,
            confidence: result.confidence,
            reasoning: result.reasoning
        )
    }
}
