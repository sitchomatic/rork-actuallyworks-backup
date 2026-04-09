import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

@MainActor
class VisionMLService {
    static let shared = VisionMLService()

    private let logger = DebugLogger.shared
    private let ciContext = CIContext()
    private var cachedSaliencyResults: [Int: [CGRect]] = [:]

    nonisolated struct OCRElement: Sendable {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
        let normalizedCenter: CGPoint

        var pixelCenter: CGPoint {
            CGPoint(x: boundingBox.midX, y: boundingBox.midY)
        }
    }

    nonisolated struct UIElementDetection: Sendable {
        let elements: [OCRElement]
        let inputFields: [OCRElement]
        let buttons: [OCRElement]
        let labels: [OCRElement]
        let imageSize: CGSize
        let processingTimeMs: Int
    }

    nonisolated struct LoginFieldDetection: Sendable {
        let emailField: FieldHit?
        let passwordField: FieldHit?
        let loginButton: FieldHit?
        let allText: [OCRElement]
        let confidence: Double
        let method: String
        let instanceMaskRegions: [MaskedRegion]
        let saliencyHotspots: [CGRect]
        let aiEnhanced: Bool

        init(emailField: FieldHit?, passwordField: FieldHit?, loginButton: FieldHit?, allText: [OCRElement], confidence: Double, method: String, instanceMaskRegions: [MaskedRegion] = [], saliencyHotspots: [CGRect] = [], aiEnhanced: Bool = false) {
            self.emailField = emailField
            self.passwordField = passwordField
            self.loginButton = loginButton
            self.allText = allText
            self.confidence = confidence
            self.method = method
            self.instanceMaskRegions = instanceMaskRegions
            self.saliencyHotspots = saliencyHotspots
            self.aiEnhanced = aiEnhanced
        }
    }

    nonisolated struct FieldHit: Sendable {
        let label: String
        let boundingBox: CGRect
        let pixelCoordinate: CGPoint
        let confidence: Float
        let nearbyText: String?
    }

    nonisolated struct MaskedRegion: Sendable {
        let instanceIndex: Int
        let boundingBox: CGRect
        let pixelArea: Int
        let overlappingText: [String]
        let predictedType: String
    }

    nonisolated struct SaliencyResult: Sendable {
        let hotspots: [CGRect]
        let primaryFocus: CGRect?
        let processingTimeMs: Int
    }

    func recognizeAllText(in image: UIImage) async -> [OCRElement] {
        guard let cgImage = image.cgImage else { return [] }
        let startTime = Date()

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.logError("VisionML: OCR perform failed", error: error, category: .automation)
            return []
        }

        guard let observations = request.results else { return [] }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var elements: [OCRElement] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let box = observation.boundingBox
            let pixelRect = CGRect(
                x: box.origin.x * imageSize.width,
                y: (1 - box.origin.y - box.height) * imageSize.height,
                width: box.width * imageSize.width,
                height: box.height * imageSize.height
            )

            let normalizedCenter = CGPoint(
                x: box.origin.x + box.width / 2,
                y: 1 - (box.origin.y + box.height / 2)
            )

            elements.append(OCRElement(
                text: candidate.string,
                boundingBox: pixelRect,
                confidence: candidate.confidence,
                normalizedCenter: normalizedCenter
            ))
        }

        let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
        logger.log("VisionML: OCR found \(elements.count) text elements in \(elapsed)ms", category: .automation, level: .debug)

        return elements
    }

    func detectLoginElements(in image: UIImage, viewportSize: CGSize) async -> LoginFieldDetection {
        let startTime = Date()
        let allText = await recognizeAllText(in: image)

        guard let cgImage = image.cgImage else {
            return LoginFieldDetection(emailField: nil, passwordField: nil, loginButton: nil, allText: allText, confidence: 0, method: "vision_ocr_failed")
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleX = viewportSize.width / imageSize.width
        let scaleY = viewportSize.height / imageSize.height

        var emailField: FieldHit?
        var passwordField: FieldHit?
        var loginButton: FieldHit?

        let emailKeywords = ["email", "e-mail", "username", "user name", "login", "email address"]
        let passwordKeywords = ["password", "pass", "pin", "secret"]
        let loginButtonKeywords = ["log in", "login", "sign in", "signin", "submit", "enter", "go"]

        for element in allText {
            let lower = element.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            for keyword in emailKeywords {
                if lower.contains(keyword) && emailField == nil {
                    let inputCoord = estimateInputFieldBelow(
                        labelBox: element.boundingBox,
                        imageSize: imageSize,
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    emailField = FieldHit(
                        label: element.text,
                        boundingBox: element.boundingBox,
                        pixelCoordinate: inputCoord,
                        confidence: element.confidence,
                        nearbyText: lower
                    )
                    break
                }
            }

            for keyword in passwordKeywords {
                if lower.contains(keyword) && passwordField == nil {
                    let inputCoord = estimateInputFieldBelow(
                        labelBox: element.boundingBox,
                        imageSize: imageSize,
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    passwordField = FieldHit(
                        label: element.text,
                        boundingBox: element.boundingBox,
                        pixelCoordinate: inputCoord,
                        confidence: element.confidence,
                        nearbyText: lower
                    )
                    break
                }
            }

            for keyword in loginButtonKeywords {
                if lower == keyword || (lower.contains(keyword) && lower.count < 20) {
                    if loginButton == nil || element.confidence > (loginButton?.confidence ?? 0) {
                        let center = CGPoint(
                            x: element.boundingBox.midX * scaleX,
                            y: element.boundingBox.midY * scaleY
                        )
                        loginButton = FieldHit(
                            label: element.text,
                            boundingBox: element.boundingBox,
                            pixelCoordinate: center,
                            confidence: element.confidence,
                            nearbyText: lower
                        )
                    }
                }
            }
        }

        let foundCount = [emailField, passwordField, loginButton].compactMap { $0 }.count
        let confidence = Double(foundCount) / 3.0

        let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
        logger.log("VisionML: login detection — email:\(emailField != nil) pass:\(passwordField != nil) btn:\(loginButton != nil) confidence:\(String(format: "%.0f%%", confidence * 100)) in \(elapsed)ms", category: .automation, level: foundCount >= 2 ? .success : .warning)

        return LoginFieldDetection(
            emailField: emailField,
            passwordField: passwordField,
            loginButton: loginButton,
            allText: allText,
            confidence: confidence,
            method: "vision_ocr"
        )
    }

    func findTextOnScreen(_ searchText: String, in image: UIImage, viewportSize: CGSize) async -> FieldHit? {
        let allText = await recognizeAllText(in: image)

        guard let cgImage = image.cgImage else { return nil }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleX = viewportSize.width / imageSize.width
        let scaleY = viewportSize.height / imageSize.height
        let searchLower = searchText.lowercased()

        var bestMatch: (element: OCRElement, score: Double)?

        for element in allText {
            let elementLower = element.text.lowercased()

            if elementLower == searchLower {
                let center = CGPoint(
                    x: element.boundingBox.midX * scaleX,
                    y: element.boundingBox.midY * scaleY
                )
                return FieldHit(
                    label: element.text,
                    boundingBox: element.boundingBox,
                    pixelCoordinate: center,
                    confidence: element.confidence,
                    nearbyText: elementLower
                )
            }

            if elementLower.contains(searchLower) {
                let score = Double(searchLower.count) / Double(elementLower.count) * Double(element.confidence)
                if bestMatch == nil || score > (bestMatch?.score ?? 0) {
                    bestMatch = (element, score)
                }
            }
        }

        if let match = bestMatch {
            let center = CGPoint(
                x: match.element.boundingBox.midX * scaleX,
                y: match.element.boundingBox.midY * scaleY
            )
            return FieldHit(
                label: match.element.text,
                boundingBox: match.element.boundingBox,
                pixelCoordinate: center,
                confidence: match.element.confidence,
                nearbyText: match.element.text.lowercased()
            )
        }

        return nil
    }

    nonisolated enum DisabledDetectionType: String, Sendable {
        case permDisabled
        case tempDisabled
        case smsDetected
        case none
    }

    func detectSuccessIndicators(in image: UIImage) async -> (successFound: Bool, errorFound: Bool, context: String?) {
        return (false, false, nil)
    }

    func detectDisabledAccount(in image: UIImage) async -> (type: DisabledDetectionType, matchedText: String?, allOCRText: String) {
        return (.none, nil, "")
    }

    func detectRectangularRegions(in image: UIImage) async -> [CGRect] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.05
        request.maximumObservations = 20

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.logError("VisionML: rectangle detection failed", error: error, category: .automation)
            return []
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        return (request.results ?? []).map { observation in
            let box = observation.boundingBox
            return CGRect(
                x: box.origin.x * imageSize.width,
                y: (1 - box.origin.y - box.height) * imageSize.height,
                width: box.width * imageSize.width,
                height: box.height * imageSize.height
            )
        }
    }

    // MARK: - Instance Segmentation (Foreground Mask)

    func detectForegroundInstances(in image: UIImage) async -> [MaskedRegion] {
        []
    }

    func detectSaliency(in image: UIImage) async -> SaliencyResult {
        SaliencyResult(hotspots: [], primaryFocus: nil, processingTimeMs: 0)
    }

    func deepDetectLoginElements(in image: UIImage, viewportSize: CGSize) async -> LoginFieldDetection {
        await detectLoginElements(in: image, viewportSize: viewportSize)
    }

    // MARK: - Region Classification

    private func classifyRegion(box: CGRect, imageSize: CGSize) -> String {
        let widthRatio = box.width / imageSize.width
        let heightRatio = box.height / imageSize.height
        let aspectRatio = box.width / max(box.height, 1)

        if widthRatio > 0.4 && heightRatio < 0.08 && aspectRatio > 4 {
            return "input_field"
        }
        if widthRatio > 0.2 && widthRatio < 0.6 && heightRatio < 0.06 && aspectRatio > 2.5 {
            return "button"
        }
        if widthRatio < 0.15 && heightRatio < 0.04 {
            return "label"
        }
        if widthRatio > 0.8 && heightRatio > 0.1 {
            return "banner"
        }
        return "unknown"
    }

    func clearSaliencyCache() {
        cachedSaliencyResults.removeAll()
    }

    private func estimateInputFieldBelow(labelBox: CGRect, imageSize: CGSize, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        let estimatedInputY = labelBox.maxY + labelBox.height * 0.8
        let centerX = labelBox.midX
        return CGPoint(
            x: centerX * scaleX,
            y: estimatedInputY * scaleY
        )
    }

    func buildVisionCalibration(from detection: LoginFieldDetection, forURL url: String) -> LoginCalibrationService.URLCalibration {
        var emailMapping: LoginCalibrationService.ElementMapping?
        if let ef = detection.emailField {
            emailMapping = LoginCalibrationService.ElementMapping(
                coordinates: ef.pixelCoordinate,
                placeholder: ef.nearbyText,
                nearbyText: ef.label
            )
        }

        var passwordMapping: LoginCalibrationService.ElementMapping?
        if let pf = detection.passwordField {
            passwordMapping = LoginCalibrationService.ElementMapping(
                coordinates: pf.pixelCoordinate,
                placeholder: pf.nearbyText,
                nearbyText: pf.label
            )
        }

        var buttonMapping: LoginCalibrationService.ElementMapping?
        if let lb = detection.loginButton {
            buttonMapping = LoginCalibrationService.ElementMapping(
                coordinates: lb.pixelCoordinate,
                nearbyText: lb.label
            )
        }

        return LoginCalibrationService.URLCalibration(
            urlPattern: url,
            emailField: emailMapping,
            passwordField: passwordMapping,
            loginButton: buttonMapping,
            notes: "Vision ML auto-calibrated (confidence: \(String(format: "%.0f%%", detection.confidence * 100)))"
        )
    }
}
