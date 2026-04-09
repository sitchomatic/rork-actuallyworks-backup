import Foundation
import UIKit

@MainActor
class StrictLoginDetectionEngine {
    static let shared = StrictLoginDetectionEngine()

    private let logger = DebugLogger.shared
    private let aiVision = UnifiedAIVisionService.shared
    private let coordEngine = CoordinateInteractionEngine.shared

    nonisolated enum DetectionModule: Sendable {
        case standard
        case dualFind
        case unifiedSession
    }

    nonisolated struct DetectionContext: Sendable {
        let module: DetectionModule
        let sessionId: String
        let pageContent: String
        let currentURL: String
        let preLoginURL: String
        let screenshot: UIImage?
    }

    nonisolated struct DetectionResult: Sendable {
        let outcome: LoginOutcome
        let phase: String
        let reason: String
        let incorrectDetectedViaDOM: Bool
        let incorrectDetectedViaOCR: Bool
        let buttonCycleCompleted: Bool
        let retryPerformed: Bool
        let detectedIncorrect: Bool
    }

    func evaluateImmediateOverrides(
        pageContent: String,
        screenshot: UIImage?,
        sessionId: String,
        automationSettings: AutomationSettings = AutomationSettings(),
        executeJS: ((String) async -> String?)? = nil
    ) async -> LoginOutcome? {
        guard let img = screenshot else { return nil }

        let context = VisionContext(site: "unknown", phase: .loginOutcome, currentURL: "", attemptNumber: 1)
        let result = await aiVision.analyzeScreenshot(img, context: context)

        if result.isPageBlank {
            logger.log("StrictDetection P1: CONNECTION_FAILURE — blank page via AI Vision", category: .evaluation, level: .warning, sessionId: sessionId)
            return .connectionFailure
        }

        if result.confidence >= 70 && result.outcome != .noAcc {
            logger.log("StrictDetection P1: \(result.outcome) via AI Vision (\(result.confidence)%) — \(result.reasoning)", category: .evaluation, level: result.outcome == .success ? .success : .warning, sessionId: sessionId)
            return result.outcome
        }

        return nil
    }

    func evaluatePostSubmit(
        session: LoginSiteWebSession,
        sessionId: String,
        buttonCycleCompleted: Bool,
        automationSettings: AutomationSettings = AutomationSettings()
    ) async -> DetectionResult {
        try? await Task.sleep(for: .seconds(2))

        guard let screenshot = await session.captureScreenshot() else {
            return DetectionResult(outcome: .connectionFailure, phase: "AI_Vision", reason: "Screenshot capture failed", incorrectDetectedViaDOM: false, incorrectDetectedViaOCR: false, buttonCycleCompleted: buttonCycleCompleted, retryPerformed: false, detectedIncorrect: false)
        }

        let currentURL = await session.getCurrentURL()
        let context = VisionContext(site: "unknown", phase: .loginOutcome, currentURL: currentURL, attemptNumber: 1)
        let result = await aiVision.analyzeScreenshot(screenshot, context: context)

        let isIncorrect = result.outcome == .noAcc && result.confidence >= 60
        logger.log("StrictDetection PostSubmit: \(result.outcome) (\(result.confidence)%) via AI Vision — \(result.reasoning)", category: .evaluation, level: result.outcome == .success ? .success : .info, sessionId: sessionId)

        return DetectionResult(
            outcome: result.outcome,
            phase: "AI_Vision",
            reason: "AI Vision: \(result.reasoning)",
            incorrectDetectedViaDOM: false,
            incorrectDetectedViaOCR: isIncorrect,
            buttonCycleCompleted: buttonCycleCompleted,
            retryPerformed: false,
            detectedIncorrect: isIncorrect
        )
    }

    func evaluateStrict(
        session: LoginSiteWebSession,
        module: DetectionModule,
        sessionId: String,
        automationSettings: AutomationSettings = AutomationSettings()
    ) async -> DetectionResult {
        try? await Task.sleep(for: .seconds(2))

        guard let screenshot = await session.captureScreenshot() else {
            return DetectionResult(outcome: .connectionFailure, phase: "AI_Vision", reason: "Screenshot capture failed", incorrectDetectedViaDOM: false, incorrectDetectedViaOCR: false, buttonCycleCompleted: true, retryPerformed: false, detectedIncorrect: false)
        }

        let currentURL = await session.getCurrentURL()
        let context = VisionContext(site: "unknown", phase: .loginOutcome, currentURL: currentURL, attemptNumber: 1)
        let result = await aiVision.analyzeScreenshot(screenshot, context: context)

        let isIncorrect = result.outcome == .noAcc && result.confidence >= 60
        logger.log("StrictDetection Strict: \(result.outcome) (\(result.confidence)%) via AI Vision — \(result.reasoning)", category: .evaluation, level: result.outcome == .success ? .success : .info, sessionId: sessionId)

        return DetectionResult(
            outcome: result.outcome,
            phase: "AI_Vision",
            reason: "AI Vision: \(result.reasoning)",
            incorrectDetectedViaDOM: false,
            incorrectDetectedViaOCR: isIncorrect,
            buttonCycleCompleted: true,
            retryPerformed: false,
            detectedIncorrect: isIncorrect
        )
    }

    func runStandardLoginDetection(
        session: LoginSiteWebSession,
        submitSelectors: [String],
        fallbackSelectors: [String],
        sessionId: String,
        automationSettings: AutomationSettings = AutomationSettings(),
        onLog: ((String, PPSRLogEntry.Level) -> Void)? = nil
    ) async -> DetectionResult {
        let executeJS: (String) async -> String? = { js in await session.executeJS(js) }

        onLog?("StrictDetection: triple-click submit via AI Vision pipeline", .info)
        let tripleResult = await coordEngine.tripleClickWithEscalatingDwell(
            selectors: submitSelectors,
            fallbackSelectors: fallbackSelectors,
            executeJS: executeJS,
            jitterPx: 3,
            sessionId: sessionId
        )
        onLog?("StrictDetection: triple-click \(tripleResult.success ? "OK" : "PARTIAL") (\(tripleResult.clicksCompleted)/3)", tripleResult.success ? .success : .warning)

        let currentURL = await session.getCurrentURL()
        let aiSettlement = AIVisionSettlementService.shared
        let settlementContext = VisionContext(site: "unknown", phase: .loginOutcome, currentURL: currentURL, attemptNumber: 1)

        let settlement = await aiSettlement.waitForSettlement(
            captureScreenshot: { await session.captureScreenshot() },
            context: settlementContext,
            maxTimeoutMs: 15000,
            sessionId: sessionId
        )

        let outcome = settlement.outcome ?? .noAcc
        let isIncorrect = outcome == .noAcc
        onLog?("StrictDetection: AI Vision settlement — \(outcome) (\(settlement.confidence)%) in \(settlement.durationMs)ms — \(settlement.reasoning)", outcome == .success ? .success : .info)

        return DetectionResult(
            outcome: outcome,
            phase: "AI_Vision_Settlement",
            reason: "AI Vision: \(settlement.reasoning)",
            incorrectDetectedViaDOM: false,
            incorrectDetectedViaOCR: isIncorrect,
            buttonCycleCompleted: true,
            retryPerformed: false,
            detectedIncorrect: isIncorrect
        )
    }

    nonisolated static func categorizeByIncorrectCount(_ completedIncorrectCycles: Int) -> LoginOutcome {
        .noAcc
    }

    nonisolated static func incorrectCountLabel(_ completedIncorrectCycles: Int) -> String {
        switch completedIncorrectCycles {
        case 0: return "unchecked"
        case 1: return "1incorrect"
        case 2: return "2incorrect"
        case 3...: return "noAcc_final"
        default: return "unknown"
        }
    }

    nonisolated static func shouldRequeue(_ completedIncorrectCycles: Int) -> Bool {
        completedIncorrectCycles > 0 && completedIncorrectCycles < 3
    }

    nonisolated static func isFinalNoAccount(_ completedIncorrectCycles: Int) -> Bool {
        completedIncorrectCycles >= 3
    }
}
