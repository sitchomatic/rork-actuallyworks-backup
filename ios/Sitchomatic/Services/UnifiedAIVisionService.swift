import Foundation
import UIKit
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated enum VisionAnalysisPhase: String, Sendable {
    case loginOutcome
    case ppsr
    case settlement
    case disabledCheck
}

nonisolated struct VisionContext: Sendable {
    let site: String
    let phase: VisionAnalysisPhase
    let currentURL: String
    let attemptNumber: Int

    init(site: String = "unknown", phase: VisionAnalysisPhase = .loginOutcome, currentURL: String = "", attemptNumber: Int = 1) {
        self.site = site
        self.phase = phase
        self.currentURL = currentURL
        self.attemptNumber = attemptNumber
    }
}

nonisolated struct VisionOutcome: Sendable {
    let outcome: LoginOutcome
    let confidence: Int
    let reasoning: String
    let isPageSettled: Bool
    let isPageBlank: Bool
    let errorText: String
    let rawResponse: String

    static let connectionFailure = VisionOutcome(
        outcome: .connectionFailure,
        confidence: 100,
        reasoning: "Page blank or unloaded",
        isPageSettled: true,
        isPageBlank: true,
        errorText: "",
        rawResponse: ""
    )

    static let noAccount = VisionOutcome(
        outcome: .noAcc,
        confidence: 60,
        reasoning: "AI Vision unavailable — defaulting to No Account",
        isPageSettled: true,
        isPageBlank: false,
        errorText: "",
        rawResponse: ""
    )
}

nonisolated struct PPSRVisionOutcome: Sendable {
    let passed: Bool
    let declined: Bool
    let summary: String
    let confidence: Int
    let errorType: String
    let suggestedAction: String
}

nonisolated struct SettlementVisionOutcome: Sendable {
    let isSettled: Bool
    let outcome: LoginOutcome?
    let confidence: Int
    let reasoning: String
    let isStillLoading: Bool
    let isPageBlank: Bool
}

@MainActor
final class UnifiedAIVisionService {
    static let shared = UnifiedAIVisionService()

    private let logger = DebugLogger.shared
    private let grok = RorkToolkitService.shared

    private let visionMaxBytes = 4_000_000

    func analyzeScreenshot(_ image: UIImage, context: VisionContext = VisionContext()) async -> VisionOutcome {
        if isBlankOrSolidColor(image) {
            logger.log("AIVision: screenshot is blank/solid — connectionFailure", category: .evaluation, level: .warning)
            return .connectionFailure
        }

        switch context.phase {
        case .loginOutcome:
            return await analyzeLoginOutcome(image, context: context)
        case .ppsr:
            let ppsr = await analyzePPSR(image, context: context)
            if ppsr.passed {
                return VisionOutcome(outcome: .success, confidence: ppsr.confidence, reasoning: ppsr.summary, isPageSettled: true, isPageBlank: false, errorText: "", rawResponse: "")
            } else if ppsr.declined {
                return VisionOutcome(outcome: .noAcc, confidence: ppsr.confidence, reasoning: ppsr.summary, isPageSettled: true, isPageBlank: false, errorText: ppsr.errorType, rawResponse: "")
            }
            return VisionOutcome(outcome: .noAcc, confidence: ppsr.confidence, reasoning: ppsr.summary, isPageSettled: true, isPageBlank: false, errorText: "", rawResponse: "")
        case .settlement:
            let settlement = await analyzeSettlement(image, context: context)
            return VisionOutcome(
                outcome: settlement.outcome ?? .noAcc,
                confidence: settlement.confidence,
                reasoning: settlement.reasoning,
                isPageSettled: settlement.isSettled,
                isPageBlank: settlement.isPageBlank,
                errorText: "",
                rawResponse: ""
            )
        case .disabledCheck:
            return await analyzeLoginOutcome(image, context: context)
        }
    }

    func analyzeLoginOutcome(_ image: UIImage, context: VisionContext) async -> VisionOutcome {
        let prompt = """
        Analyze this casino/gambling website login page screenshot. Determine the EXACT login outcome.

        You MUST respond with ONLY valid JSON in this exact format:
        {
          "outcome": "noAcc",
          "confidence": 90,
          "reasoning": "brief explanation",
          "errorText": "",
          "isPageSettled": true,
          "isPageBlank": false,
          "isStillLoading": false
        }

        outcome MUST be one of: "success", "noAcc", "permDisabled", "tempDisabled", "smsDetected", "connectionFailure"

        Rules:
        - "success" = you see a lobby, dashboard, game grid, user balance, "recommended for you", "last played" — NOT the login form
        - "noAcc" = you see "incorrect password", "invalid credentials", "wrong password", error banner, login form still showing after submit, or ANY error that isn't disabled/sms
        - "permDisabled" = you see "has been disabled", "account suspended", "permanently banned", "account closed"
        - "tempDisabled" = you see "temporarily disabled", "too many attempts", "temporarily locked"
        - "smsDetected" = you see SMS verification, "verification code", "enter code", phone verification prompt
        - "connectionFailure" = blank page, error page, 403/404/500, "page not found", no content loaded
        - isPageSettled = true if the page has finished loading (no spinners, no loading text)
        - isStillLoading = true if you see loading spinners, "please wait", skeleton screens
        - errorText = exact error message text visible on screen, empty string if none

        Site: \(context.site)
        URL: \(context.currentURL)
        """

        if let result = await grok.analyzeScreenshotWithVision(image: image, prompt: prompt) {
            return mapGrokResultToOutcome(result)
        }

        logger.log("AIVision: Grok Vision unavailable — falling back to on-device analysis", category: .evaluation, level: .warning)
        return await onDeviceFallbackAnalysis(image, context: context)
    }

    func analyzePPSR(_ image: UIImage, context: VisionContext) async -> PPSRVisionOutcome {
        let prompt = """
        Analyze this Australian PPSR vehicle check payment page screenshot.

        Respond with ONLY valid JSON:
        {
          "passed": false,
          "declined": false,
          "summary": "",
          "confidence": 90,
          "errorType": "none",
          "suggestedAction": "retry"
        }

        Rules:
        - passed = true if you see a PPSR certificate, success message, "search complete", "no interests found"
        - declined = true if you see "declined by your institution", "payment failed", "card declined", "insufficient funds"
        - errorType: "none", "institution_decline", "expired_card", "insufficient_funds", "network_error"
        - suggestedAction: "proceed", "rotate_card", "retry"
        """

        if let result = await grok.analyzeScreenshotWithVision(image: image, prompt: prompt) {
            return parsePPSRFromGrok(result)
        }

        return await onDevicePPSRFallback(image)
    }

    func analyzeSettlement(_ image: UIImage, context: VisionContext) async -> SettlementVisionOutcome {
        let prompt = """
        Analyze this web page screenshot to determine if the page has finished loading after a form submission.

        Respond with ONLY valid JSON:
        {
          "isSettled": true,
          "outcome": null,
          "confidence": 80,
          "reasoning": "",
          "isStillLoading": false,
          "isPageBlank": false
        }

        Rules:
        - isSettled = true if the page has completed loading (no spinners, progress bars, or "loading" text)
        - isStillLoading = true if you see loading indicators, spinners, "please wait", "processing", skeleton screens
        - isPageBlank = true if the page appears blank, white, or has no meaningful content
        - outcome = one of "success", "noAcc", "permDisabled", "tempDisabled", "smsDetected", "connectionFailure", or null if unclear
        - If you can determine a login outcome, set it. If page is still loading, set outcome to null.

        Site: \(context.site)
        """

        if let result = await grok.analyzeScreenshotWithVision(image: image, prompt: prompt) {
            return parseSettlementFromGrok(result)
        }

        return SettlementVisionOutcome(isSettled: true, outcome: nil, confidence: 30, reasoning: "Grok unavailable — assuming settled", isStillLoading: false, isPageBlank: false)
    }

    private func mapGrokResultToOutcome(_ result: GrokVisionAnalysisResult) -> VisionOutcome {
        let raw = result.rawResponse
        let jsonDict = extractJSONDict(from: raw)

        let outcomeStr = jsonDict["outcome"] as? String ?? ""
        let confidence = jsonDict["confidence"] as? Int ?? result.confidence
        let reasoning = jsonDict["reasoning"] as? String ?? ""
        let errorText = jsonDict["errorText"] as? String ?? result.errorText
        let isSettled = jsonDict["isPageSettled"] as? Bool ?? true
        let isBlank = jsonDict["isPageBlank"] as? Bool ?? false
        let isLoading = jsonDict["isStillLoading"] as? Bool ?? false

        let outcome: LoginOutcome
        if !outcomeStr.isEmpty {
            outcome = stringToLoginOutcome(outcomeStr)
        } else {
            outcome = grokResultToOutcome(result)
        }

        return VisionOutcome(
            outcome: outcome,
            confidence: confidence,
            reasoning: reasoning.isEmpty ? describeGrokResult(result) : reasoning,
            isPageSettled: isSettled && !isLoading,
            isPageBlank: isBlank,
            errorText: errorText,
            rawResponse: raw
        )
    }

    private func grokResultToOutcome(_ r: GrokVisionAnalysisResult) -> LoginOutcome {
        if r.loginSuccessful { return .success }
        if r.isPermanentBan { return .permDisabled }
        if r.isTempLock { return .tempDisabled }
        if r.captchaDetected { return .connectionFailure }
        if r.hasError { return .noAcc }
        if r.accountDisabled { return .permDisabled }
        return .noAcc
    }

    private func describeGrokResult(_ r: GrokVisionAnalysisResult) -> String {
        if r.loginSuccessful { return "Login successful — lobby/dashboard detected" }
        if r.isPermanentBan { return "Permanent ban — 'has been disabled'" }
        if r.isTempLock { return "Temporary lock — 'temporarily disabled'" }
        if r.hasError { return "Error detected: \(r.errorText)" }
        return "No definitive markers found"
    }

    private func parsePPSRFromGrok(_ result: GrokVisionAnalysisResult) -> PPSRVisionOutcome {
        let dict = extractJSONDict(from: result.rawResponse)
        return PPSRVisionOutcome(
            passed: dict["passed"] as? Bool ?? result.ppsrPassed,
            declined: dict["declined"] as? Bool ?? result.ppsrDeclined,
            summary: dict["summary"] as? String ?? result.rawResponse.prefix(200).description,
            confidence: dict["confidence"] as? Int ?? result.confidence,
            errorType: dict["errorType"] as? String ?? "none",
            suggestedAction: dict["suggestedAction"] as? String ?? "retry"
        )
    }

    private func parseSettlementFromGrok(_ result: GrokVisionAnalysisResult) -> SettlementVisionOutcome {
        let dict = extractJSONDict(from: result.rawResponse)
        let outcomeStr = dict["outcome"] as? String
        let outcome: LoginOutcome? = outcomeStr.flatMap { str in
            str == "null" || str.isEmpty ? nil : stringToLoginOutcome(str)
        }
        return SettlementVisionOutcome(
            isSettled: dict["isSettled"] as? Bool ?? true,
            outcome: outcome,
            confidence: dict["confidence"] as? Int ?? result.confidence,
            reasoning: dict["reasoning"] as? String ?? "",
            isStillLoading: dict["isStillLoading"] as? Bool ?? false,
            isPageBlank: dict["isPageBlank"] as? Bool ?? false
        )
    }

    private func onDeviceFallbackAnalysis(_ image: UIImage, context: VisionContext) async -> VisionOutcome {
        let ocrText = await extractOCRText(from: image)
        let ocrLower = ocrText.lowercased()

        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
            return .connectionFailure
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let appleResult = await appleFoundationModelAnalysis(ocrText: ocrLower, context: context) {
                return appleResult
            }
        }
        #endif

        return onDeviceKeywordFallback(ocrLower: ocrLower)
    }

    private func onDeviceKeywordFallback(ocrLower: String) -> VisionOutcome {
        if ocrLower.contains("has been disabled") {
            return VisionOutcome(outcome: .permDisabled, confidence: 95, reasoning: "On-device OCR: 'has been disabled'", isPageSettled: true, isPageBlank: false, errorText: "has been disabled", rawResponse: "")
        }
        if ocrLower.contains("temporarily disabled") {
            return VisionOutcome(outcome: .tempDisabled, confidence: 95, reasoning: "On-device OCR: 'temporarily disabled'", isPageSettled: true, isPageBlank: false, errorText: "temporarily disabled", rawResponse: "")
        }
        if ocrLower.contains("recommended for you") || ocrLower.contains("last played") || ocrLower.contains("my account") || ocrLower.contains("balance") {
            return VisionOutcome(outcome: .success, confidence: 85, reasoning: "On-device OCR: success markers found", isPageSettled: true, isPageBlank: false, errorText: "", rawResponse: "")
        }
        if ocrLower.contains("incorrect") || ocrLower.contains("invalid") || ocrLower.contains("wrong password") {
            return VisionOutcome(outcome: .noAcc, confidence: 85, reasoning: "On-device OCR: error keywords found", isPageSettled: true, isPageBlank: false, errorText: "incorrect/invalid", rawResponse: "")
        }
        let smsKeywords = ["sms", "verification code", "verify your phone", "enter the code", "phone verification", "enter code", "send code"]
        for kw in smsKeywords {
            if ocrLower.contains(kw) {
                return VisionOutcome(outcome: .smsDetected, confidence: 80, reasoning: "On-device OCR: SMS keyword '\(kw)'", isPageSettled: true, isPageBlank: false, errorText: "", rawResponse: "")
            }
        }
        return VisionOutcome(outcome: .noAcc, confidence: 40, reasoning: "On-device OCR: no definitive markers — classified as No Account", isPageSettled: true, isPageBlank: false, errorText: "", rawResponse: "")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func appleFoundationModelAnalysis(ocrText: String, context: VisionContext) async -> VisionOutcome? {
        guard SystemLanguageModel.default.isAvailable else { return nil }
        do {
            let session = LanguageModelSession(
                instructions: """
                You classify login outcomes for casino websites. Given OCR text from a screenshot, determine the outcome.
                Respond with ONLY JSON: {"outcome":"success|noAcc|permDisabled|tempDisabled|smsDetected|connectionFailure","confidence":0-100,"reasoning":"brief"}
                """
            )
            let truncated = String(ocrText.prefix(2000))
            let response = try await session.respond(to: "Site: \(context.site)\nOCR text:\n\(truncated)")
            let dict = extractJSONDict(from: response.content)
            let outcomeStr = dict["outcome"] as? String ?? "noAcc"
            let conf = dict["confidence"] as? Int ?? 50
            let reason = dict["reasoning"] as? String ?? "Apple on-device model"
            return VisionOutcome(
                outcome: stringToLoginOutcome(outcomeStr),
                confidence: conf,
                reasoning: "Apple AI: \(reason)",
                isPageSettled: true,
                isPageBlank: false,
                errorText: "",
                rawResponse: response.content
            )
        } catch {
            logger.logError("AIVision: Apple FoundationModels failed", error: error, category: .evaluation)
            return nil
        }
    }
    #endif

    private func onDevicePPSRFallback(_ image: UIImage) async -> PPSRVisionOutcome {
        let ocrText = await extractOCRText(from: image)
        let lower = ocrText.lowercased()
        let passed = lower.contains("search complete") || lower.contains("no interests") || lower.contains("certificate")
        let declined = lower.contains("institution") || lower.contains("declined") || lower.contains("payment failed") || lower.contains("insufficient")
        return PPSRVisionOutcome(
            passed: passed && !declined,
            declined: declined,
            summary: String(ocrText.prefix(200)),
            confidence: (passed || declined) ? 60 : 30,
            errorType: declined ? "institution_decline" : "none",
            suggestedAction: passed ? "proceed" : declined ? "rotate_card" : "retry"
        )
    }

    func extractOCRText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        guard let observations = request.results else { return "" }
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }

    private func isBlankOrSolidColor(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let w = min(cgImage.width, 40)
        let h = min(cgImage.height, 40)
        guard w > 0 && h > 0 else { return true }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rS = 0, gS = 0, bS = 0, rQ = 0, gQ = 0, bQ = 0
        let n = w * h
        for i in 0..<n {
            let r = Int(pixels[i * 4]), g = Int(pixels[i * 4 + 1]), b = Int(pixels[i * 4 + 2])
            rS += r; gS += g; bS += b
            rQ += r * r; gQ += g * g; bQ += b * b
        }
        let rV = (rQ / n) - (rS / n) * (rS / n)
        let gV = (gQ / n) - (gS / n) * (gS / n)
        let bV = (bQ / n) - (bS / n) * (bS / n)
        return (rV + gV + bV) < 150
    }

    private nonisolated func stringToLoginOutcome(_ str: String) -> LoginOutcome {
        switch str.lowercased() {
        case "success": return .success
        case "permdisabled": return .permDisabled
        case "tempdisabled": return .tempDisabled
        case "noacc": return .noAcc
        case "smsdetected": return .smsDetected
        case "connectionfailure": return .connectionFailure
        case "timeout": return .timeout
        default: return .noAcc
        }
    }

    private func extractJSONDict(from text: String) -> [String: Any] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonStr: String
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            jsonStr = String(cleaned[start.lowerBound...end.upperBound])
        } else {
            jsonStr = cleaned
        }
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}
