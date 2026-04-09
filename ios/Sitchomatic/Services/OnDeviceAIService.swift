import Foundation
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated struct AIAnalysisPPSRResult: Sendable {
    let passed: Bool
    let declined: Bool
    let summary: String
    let confidence: Int
    let errorType: String
    let suggestedAction: String
}

nonisolated struct AIAnalysisLoginResult: Sendable {
    let loginSuccessful: Bool
    let hasError: Bool
    let errorText: String
    let accountDisabled: Bool
    let suggestedAction: String
    let confidence: Int
}

nonisolated struct AIFieldMappingResult: Sendable {
    let emailLabels: [String]
    let passwordLabels: [String]
    let buttonLabels: [String]
    let isStandard: Bool
    let confidence: Int
}

nonisolated struct AIFlowPredictionResult: Sendable {
    let nextAction: String
    let reason: String
    let shouldContinue: Bool
    let riskLevel: String
}

@MainActor
final class OnDeviceAIService {
    static let shared = OnDeviceAIService()

    private let logger = DebugLogger.shared
    private let aiVision = UnifiedAIVisionService.shared
    private let grok = RorkToolkitService.shared

    var isAvailable: Bool {
        GrokAISetup.isConfigured || appleModelAvailable
    }

    private var appleModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    func analyzePPSRResponse(pageContent: String) async -> AIAnalysisPPSRResult? {
        return AIAnalysisPPSRResult(passed: false, declined: false, summary: "Use AI Vision screenshot analysis instead", confidence: 0, errorType: "none", suggestedAction: "retry")
    }

    func analyzePPSRScreenshot(_ image: UIImage) async -> PPSRVisionOutcome {
        let context = VisionContext(site: "ppsr", phase: .ppsr, currentURL: "")
        return await aiVision.analyzePPSR(image, context: context)
    }

    func analyzeLoginPage(pageContent: String, ocrTexts: [String]) async -> AIAnalysisLoginResult? {
        return AIAnalysisLoginResult(loginSuccessful: false, hasError: false, errorText: "", accountDisabled: false, suggestedAction: "unknown", confidence: 0)
    }

    func analyzeLoginScreenshot(_ image: UIImage) async -> VisionOutcome {
        let context = VisionContext(site: "unknown", phase: .loginOutcome, currentURL: "")
        return await aiVision.analyzeScreenshot(image, context: context)
    }

    func mapOCRToFields(ocrTexts: [String]) async -> AIFieldMappingResult? {
        nil
    }

    func predictFlowOutcome(currentStep: String, pageContent: String, previousActions: [String]) async -> AIFlowPredictionResult? {
        AIFlowPredictionResult(nextAction: "click", reason: "AI Vision pipeline — proceed", shouldContinue: true, riskLevel: "low")
    }

    func generateVariantEmail(base: String) async -> String? {
        if GrokAISetup.isConfigured {
            let result = await grok.generateFast(
                systemPrompt: "Generate a Gmail dot-trick variant of the given email. Return only the email address, nothing else.",
                userPrompt: "Create a variant of: \(base)"
            )
            if let r = result?.trimmingCharacters(in: .whitespacesAndNewlines), r.contains("@") {
                return r
            }
        }
        return nil
    }
}
