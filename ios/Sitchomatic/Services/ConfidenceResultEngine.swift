import Foundation
import UIKit

@MainActor
class ConfidenceResultEngine {
    static let shared = ConfidenceResultEngine()

    private let logger = DebugLogger.shared
    private let aiVision = UnifiedAIVisionService.shared

    nonisolated struct ConfidenceResult: Sendable {
        let outcome: LoginOutcome
        let confidence: Double
        let compositeScore: Double
        let signalBreakdown: [SignalContribution]
        let reasoning: String
    }

    nonisolated struct SignalContribution: Sendable {
        let source: String
        let weight: Double
        let rawScore: Double
        let weightedScore: Double
        let detail: String
    }

    func evaluate(
        pageContent: String,
        currentURL: String,
        preLoginURL: String,
        pageTitle: String,
        successTextFound: Bool,
        redirectedToHomepage: Bool,
        navigationDetected: Bool,
        contentChanged: Bool,
        responseTimeMs: Int,
        screenshot: UIImage? = nil,
        httpStatus: Int? = nil
    ) async -> ConfidenceResult {
        if let screenshot {
            let context = VisionContext(site: "unknown", phase: .loginOutcome, currentURL: currentURL, attemptNumber: 1)
            let result = await aiVision.analyzeScreenshot(screenshot, context: context)

            let signal = SignalContribution(
                source: "AI_VISION",
                weight: 1.0,
                rawScore: Double(result.confidence) / 100.0,
                weightedScore: Double(result.confidence) / 100.0,
                detail: "AI Vision: \(result.reasoning)"
            )

            return ConfidenceResult(
                outcome: result.outcome,
                confidence: Double(result.confidence) / 100.0,
                compositeScore: Double(result.confidence) / 100.0,
                signalBreakdown: [signal],
                reasoning: "AI Vision: \(result.reasoning)"
            )
        }

        return ConfidenceResult(
            outcome: .noAcc,
            confidence: 0.3,
            compositeScore: 0.3,
            signalBreakdown: [SignalContribution(source: "NO_SCREENSHOT", weight: 1.0, rawScore: 0.3, weightedScore: 0.3, detail: "No screenshot available for AI Vision")],
            reasoning: "No screenshot — classified as No Account"
        )
    }

    func recordOutcomeFeedback(host: String, predictedOutcome: LoginOutcome, actualOutcome: LoginOutcome, confidence: Double, pageContent: String) {
    }
}
