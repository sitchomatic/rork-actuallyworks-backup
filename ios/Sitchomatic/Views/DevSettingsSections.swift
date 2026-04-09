import SwiftUI

// MARK: - 1. Detection & Selectors (True Detection + Field Detection + Login Button Detection Mode)

struct DevDetectionSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Detection & Selectors", settings: $settings) {
            Section {
                devToggle("TRUE DETECTION Enabled", $settings.trueDetectionEnabled)
                devToggle("TRUE DETECTION Priority", $settings.trueDetectionPriority)
                    .disabled(!settings.trueDetectionEnabled)
                    .opacity(settings.trueDetectionEnabled ? 1 : 0.4)
                devToggle("Strict Waits", $settings.trueDetectionStrictWaits)
                    .disabled(!settings.trueDetectionEnabled)
                    .opacity(settings.trueDetectionEnabled ? 1 : 0.4)
                devToggle("No Proxy Rotation", $settings.trueDetectionNoProxyRotation)
                devToggle("Ignore Placeholders", $settings.trueDetectionIgnorePlaceholders)
                devToggle("Ignore XPaths", $settings.trueDetectionIgnoreXPaths)
                devToggle("Ignore ClassNames", $settings.trueDetectionIgnoreClassNames)
            } header: { Text("True Detection Protocol") }

            Section {
                devInt("Hard Pause (ms)", $settings.trueDetectionHardPauseMs)
                devInt("Triple Click Count", $settings.trueDetectionTripleClickCount)
                devInt("Triple Click Delay (ms)", $settings.trueDetectionTripleClickDelayMs)
                devInt("Submit Cycle Count", $settings.trueDetectionSubmitCycleCount)
                devInt("Button Recovery Timeout (ms)", $settings.trueDetectionButtonRecoveryTimeoutMs)
                devInt("Max Attempts", $settings.trueDetectionMaxAttempts)
                devInt("Post Click Wait (ms)", $settings.trueDetectionPostClickWaitMs)
                devInt("Cooldown (minutes)", $settings.trueDetectionCooldownMinutes)
                if settings.trueDetectionMaxAttempts < settings.minAttemptsBeforeNoAcc {
                    devValidationWarning("Max Attempts (\(settings.trueDetectionMaxAttempts)) < Min Attempts Before NoAcc (\(settings.minAttemptsBeforeNoAcc)) — credentials may be prematurely marked as no-account")
                }
            } header: { Text("True Detection Timing") }

            Section {
                devString("Email Selector", $settings.joeEmailSelector)
                devString("Password Selector", $settings.joePasswordSelector)
                devString("Submit Selector", $settings.joeSubmitSelector)
            } header: {
                Label("Joe Fortune Selectors", systemImage: "suit.spade.fill")
            } footer: {
                Text("#username, #password, #loginSubmit")
            }

            Section {
                devString("Email Selector", $settings.ignEmailSelector)
                devString("Password Selector", $settings.ignPasswordSelector)
                devString("Submit Selector", $settings.ignSubmitSelector)
            } header: {
                Label("Ignition Selectors", systemImage: "flame.fill")
            } footer: {
                Text("#email, #login-password, #login-submit")
            }

            Section {
                devStringArray("Success Markers", $settings.trueDetectionSuccessMarkers)
                devStringArray("Terminal Keywords", $settings.trueDetectionTerminalKeywords)
                devStringArray("Error Banner Selectors", $settings.trueDetectionErrorBannerSelectors)
                if !settings.errorBannerDetection {
                    devInfoNote("Error banner selectors inactive — enable Error Banner Detection in Result Evaluation to activate.")
                }
            } header: { Text("Keywords & Error Banners") }

            Section {
                devToggle("Field Verification", $settings.fieldVerificationEnabled)
                devDouble("Field Verification Timeout (s)", $settings.fieldVerificationTimeout)
                devToggle("Auto Calibration", $settings.autoCalibrationEnabled)
                devToggle("Vision ML Calibration Fallback", $settings.visionMLCalibrationFallback)
                    .disabled(!settings.autoCalibrationEnabled)
                    .opacity(settings.autoCalibrationEnabled ? 1 : 0.4)
                devDouble("Calibration Confidence Threshold", $settings.calibrationConfidenceThreshold)
            } header: { Text("Field Detection") }

            Section {
                Picker("Detection Mode", selection: $settings.loginButtonDetectionMode) {
                    ForEach(AutomationSettings.ButtonDetectionMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }.font(.subheadline)
                devStringArray("Button Text Matches", $settings.loginButtonTextMatches)
                devString("Custom Selector", $settings.loginButtonCustomSelector)
                devInt("Max Candidates", $settings.loginButtonMaxCandidates)
                devDouble("Confidence Threshold", $settings.loginButtonConfidenceThreshold)
                devInt("Min Button Size (px)", $settings.loginButtonMinSizePx)
                devToggle("Visibility Check", $settings.loginButtonVisibilityCheck)
            } header: { Text("Login Button Detection") }

            Section {
                devInt("Max Submit Cycles", $settings.maxSubmitCycles)
                devToggle("Prefer Calibrated Patterns First", $settings.preferCalibratedPatternsFirst)
                devToggle("Pattern Learning", $settings.patternLearningEnabled)
                devStringArray("Enabled Patterns", $settings.enabledPatterns)
                devStringArray("Pattern Priority Order", $settings.patternPriorityOrder)
                devInfoNote("First enabled pattern in priority order is used for cycle 1.")
            } header: { Text("Pattern Strategy") }
        }
    }
}

// MARK: - 2. Typing & Input (Credential Entry + Form Interaction + Human Simulation)

struct DevTypingInputSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Typing & Input", settings: $settings) {
            Section {
                devInt("Typing Speed Min (ms)", $settings.typingSpeedMinMs)
                devInt("Typing Speed Max (ms)", $settings.typingSpeedMaxMs)
                if settings.typingSpeedMinMs > settings.typingSpeedMaxMs {
                    devValidationWarning("Min typing speed exceeds Max — values will be clamped")
                }
                devToggle("Typing Jitter", $settings.typingJitterEnabled)
                devToggle("Occasional Backspace", $settings.occasionalBackspaceEnabled)
                devDouble("Backspace / Typo Probability", $settings.backspaceProbability)
                    .disabled(!settings.occasionalBackspaceEnabled)
                    .opacity(settings.occasionalBackspaceEnabled ? 1 : 0.4)
            } header: { Text("Typing Speed") }

            Section {
                devInt("Field Focus Delay (ms)", $settings.fieldFocusDelayMs)
                devInt("Inter-Field Delay (ms)", $settings.interFieldDelayMs)
                devInt("Pre-Fill Pause Min (ms)", $settings.preFillPauseMinMs)
                devInt("Pre-Fill Pause Max (ms)", $settings.preFillPauseMaxMs)
                if settings.preFillPauseMinMs > settings.preFillPauseMaxMs {
                    devValidationWarning("Min pre-fill pause exceeds Max")
                }
            } header: { Text("Field Timing") }

            Section {
                devToggle("Clear Fields Before Typing", $settings.clearFieldsBeforeTyping)
                Picker("Clear Field Method", selection: $settings.clearFieldMethod) {
                    ForEach(AutomationSettings.FieldClearMethod.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }.font(.subheadline)
                    .disabled(!settings.clearFieldsBeforeTyping)
                    .opacity(settings.clearFieldsBeforeTyping ? 1 : 0.4)
                devToggle("Tab Between Fields", $settings.tabBetweenFields)
                devToggle("Click Field Before Typing", $settings.clickFieldBeforeTyping)
            } header: { Text("Field Interaction") }

            Section {
                devToggle("Verify Field Value After Typing", $settings.verifyFieldValueAfterTyping)
                devToggle("Retype On Verification Failure", $settings.retypeOnVerificationFailure)
                    .disabled(!settings.verifyFieldValueAfterTyping)
                    .opacity(settings.verifyFieldValueAfterTyping ? 1 : 0.4)
                devInt("Max Retype Attempts", $settings.maxRetypeAttempts)
                    .disabled(!settings.verifyFieldValueAfterTyping || !settings.retypeOnVerificationFailure)
                    .opacity(settings.verifyFieldValueAfterTyping && settings.retypeOnVerificationFailure ? 1 : 0.4)
            } header: { Text("Verification") }

            Section {
                devToggle("Password Field Unmask Check", $settings.passwordFieldUnmaskCheck)
                devToggle("Auto Detect Remember Me", $settings.autoDetectRememberMe)
                devToggle("Uncheck Remember Me", $settings.uncheckRememberMe)
                    .disabled(!settings.autoDetectRememberMe)
                    .opacity(settings.autoDetectRememberMe ? 1 : 0.4)
                devToggle("Dismiss Autofill Suggestions", $settings.dismissAutofillSuggestions)
                devToggle("Handle Password Managers", $settings.handlePasswordManagers)
            } header: { Text("Form Extras") }

            Section {
                devToggle("Human Mouse Movement", $settings.humanMouseMovement)
                devToggle("Human Scroll Jitter", $settings.humanScrollJitter)
                devToggle("Random Pre-Action Pause", $settings.randomPreActionPause)
                devInt("Pre-Action Pause Min (ms)", $settings.preActionPauseMinMs)
                    .disabled(!settings.randomPreActionPause)
                    .opacity(settings.randomPreActionPause ? 1 : 0.4)
                devInt("Pre-Action Pause Max (ms)", $settings.preActionPauseMaxMs)
                    .disabled(!settings.randomPreActionPause)
                    .opacity(settings.randomPreActionPause ? 1 : 0.4)
                if settings.preActionPauseMinMs > settings.preActionPauseMaxMs {
                    devValidationWarning("Min pre-action pause exceeds Max")
                }
                devToggle("Gaussian Timing Distribution", $settings.gaussianTimingDistribution)
            } header: { Text("Human Simulation") }
        }
    }
}

// MARK: - 3. Submit & Click (Submit Behavior + Login Button Click + Settlement Gate)

struct DevSubmitClickSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Submit & Click", settings: $settings) {
            Section {
                devInt("Submit Retry Count", $settings.submitRetryCount)
                devInt("Submit Retry Delay (ms)", $settings.submitRetryDelayMs)
                devDouble("Wait For Response (s)", $settings.waitForResponseSeconds)
                devToggle("Rapid Poll", $settings.rapidPollEnabled)
                devInt("Rapid Poll Interval (ms)", $settings.rapidPollIntervalMs)
                    .disabled(!settings.rapidPollEnabled)
                    .opacity(settings.rapidPollEnabled ? 1 : 0.4)
            } header: { Text("Submit Behavior") }

            Section {
                Picker("Click Method", selection: $settings.loginButtonClickMethod) {
                    ForEach(AutomationSettings.ButtonClickMethod.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }.font(.subheadline)
                devInt("Pre-Click Delay (ms)", $settings.loginButtonPreClickDelayMs)
                devInt("Post-Click Delay (ms)", $settings.loginButtonPostClickDelayMs)
                devToggle("Double Click Guard", $settings.loginButtonDoubleClickGuard)
                devInt("Double Click Window (ms)", $settings.loginButtonDoubleClickWindowMs)
                    .disabled(!settings.loginButtonDoubleClickGuard)
                    .opacity(settings.loginButtonDoubleClickGuard ? 1 : 0.4)
                devToggle("Scroll Into View", $settings.loginButtonScrollIntoView)
                devToggle("Wait For Enabled", $settings.loginButtonWaitForEnabled)
                devInt("Wait For Enabled Timeout (ms)", $settings.loginButtonWaitForEnabledTimeoutMs)
                    .disabled(!settings.loginButtonWaitForEnabled)
                    .opacity(settings.loginButtonWaitForEnabled ? 1 : 0.4)
                devToggle("Focus Before Click", $settings.loginButtonFocusBeforeClick)
            } header: { Text("Click Behavior") }

            Section {
                devToggle("Hover Before Click", $settings.loginButtonHoverBeforeClick)
                devInt("Hover Dwell (ms)", $settings.v42HoverDwellMs)
                    .disabled(!settings.loginButtonHoverBeforeClick)
                    .opacity(settings.loginButtonHoverBeforeClick ? 1 : 0.4)
                devInfoNote("Unified hover dwell — used by both Settlement Gate and Login Button click.")
                devToggle("Click Offset Jitter", $settings.loginButtonClickOffsetJitter)
                devInt("Click Jitter (px)", $settings.v42ClickJitterPx)
                    .disabled(!settings.loginButtonClickOffsetJitter)
                    .opacity(settings.loginButtonClickOffsetJitter ? 1 : 0.4)
                devInfoNote("Unified click jitter — used by Settlement Gate coordinate interaction.")
            } header: { Text("Hover & Jitter") }

            Section {
                devToggle("Settlement Gate Enabled", $settings.v42SettlementGateEnabled)
                devInt("Settlement Max Timeout (ms)", $settings.v42SettlementMaxTimeoutMs)
                    .disabled(!settings.v42SettlementGateEnabled)
                    .opacity(settings.v42SettlementGateEnabled ? 1 : 0.4)
                devInt("Button Stability (ms)", $settings.v42ButtonStabilityMs)
                devInt("Human Variance Min (ms)", $settings.v42HumanVarianceMinMs)
                devInt("Human Variance Max (ms)", $settings.v42HumanVarianceMaxMs)
                if settings.v42HumanVarianceMinMs > settings.v42HumanVarianceMaxMs {
                    devValidationWarning("Min human variance exceeds Max")
                }
                devToggle("Strict Classification", $settings.v42StrictClassification)
                devToggle("Coordinate Interaction Only", $settings.v42CoordinateInteractionOnly)
            } header: { Text("Settlement Gate") }

            Section {
                devInt("Page Load Extra Delay (ms)", $settings.pageLoadExtraDelayMs)
                devInt("Submit Button Wait Delay (ms)", $settings.submitButtonWaitDelayMs)
            } header: { Text("Extra Waits") }
        }
    }
}

// MARK: - 4. Result Evaluation (Post-Submit + Error Classification)

struct DevResultEvalSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Result Evaluation", settings: $settings) {
            Section {
                devToggle("Redirect Detection", $settings.redirectDetection)
                devToggle("Error Banner Detection", $settings.errorBannerDetection)
                devToggle("Content Change Detection", $settings.contentChangeDetection)
                Picker("Evaluation Strictness", selection: $settings.evaluationStrictness) {
                    ForEach(AutomationSettings.EvaluationStrictness.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }.font(.subheadline)
                devToggle("Capture Page Content", $settings.capturePageContent)
            } header: { Text("Post-Submit Evaluation") }

            Section {
                devToggle("Network Error Auto Retry", $settings.networkErrorAutoRetry)
                devToggle("SSL Error Auto Retry", $settings.sslErrorAutoRetry)
                devToggle("HTTP 403 Mark As Blocked", $settings.http403MarkAsBlocked)
                devInt("HTTP 429 Retry After (s)", $settings.http429RetryAfterSeconds)
                devToggle("HTTP 5xx Auto Retry", $settings.http5xxAutoRetry)
                devToggle("Connection Reset Auto Retry", $settings.connectionResetAutoRetry)
                devToggle("DNS Failure Auto Retry", $settings.dnsFailureAutoRetry)
            } header: { Text("Error Classification") }
        }
    }
}

// MARK: - 5. All Delays

struct DevAllDelaysSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("All Delays", settings: $settings) {
            Section {
                devInt("Global Pre-Action (ms)", $settings.globalPreActionDelayMs)
                devInt("Global Post-Action (ms)", $settings.globalPostActionDelayMs)
                devInt("Pre-Navigation (ms)", $settings.preNavigationDelayMs)
                devInt("Post-Navigation (ms)", $settings.postNavigationDelayMs)
                devInt("Pre-Typing (ms)", $settings.preTypingDelayMs)
                devInt("Post-Typing (ms)", $settings.postTypingDelayMs)
                devInt("Pre-Submit (ms)", $settings.preSubmitDelayMs)
                devInt("Post-Submit (ms)", $settings.postSubmitDelayMs)
            } header: { Text("Action Delays") }

            Section {
                devInt("Between Attempts (ms)", $settings.betweenAttemptsDelayMs)
                devDouble("V4.2 Inter-Attempt Min (s)", $settings.v42InterAttemptDelayMinSec)
                devDouble("V4.2 Inter-Attempt Max (s)", $settings.v42InterAttemptDelayMaxSec)
                if settings.v42InterAttemptDelayMinSec > settings.v42InterAttemptDelayMaxSec {
                    devValidationWarning("Min inter-attempt delay exceeds Max")
                }
                devInfoNote("Between Attempts (ms) is used by DualFind. V4.2 Inter-Attempt delays are used by Unified Sessions.")
                devInt("Between Credentials (ms)", $settings.betweenCredentialsDelayMs)
            } header: { Text("Between-Attempt Delays") }

            Section {
                devInt("Page Stabilization (ms)", $settings.pageStabilizationDelayMs)
                devInt("AJAX Settle (ms)", $settings.ajaxSettleDelayMs)
                devInt("DOM Mutation Settle (ms)", $settings.domMutationSettleMs)
                devInt("Animation Settle (ms)", $settings.animationSettleDelayMs)
                devInt("Redirect Follow (ms)", $settings.redirectFollowDelayMs)
            } header: { Text("Settlement Delays") }

            Section {
                devInt("CAPTCHA Detection (ms)", $settings.captchaDetectionDelayMs)
                devInt("Error Recovery (ms)", $settings.errorRecoveryDelayMs)
                devInt("Session Cooldown (ms)", $settings.sessionCooldownDelayMs)
                devInt("Proxy Rotation (ms)", $settings.proxyRotationDelayMs)
                devInt("VPN Reconnect (ms)", $settings.vpnReconnectDelayMs)
            } header: { Text("Recovery Delays") }

            Section {
                devToggle("Auto Fallback WG \u{2192} OVPN", $settings.autoFallbackWGtoOVPN)
                devToggle("Auto Fallback OVPN \u{2192} SOCKS5", $settings.autoFallbackOVPNtoSOCKS5)
                devToggle("Delay Randomization", $settings.delayRandomizationEnabled)
                devInt("Delay Randomization %", $settings.delayRandomizationPercent)
                    .disabled(!settings.delayRandomizationEnabled)
                    .opacity(settings.delayRandomizationEnabled ? 1 : 0.4)
            } header: { Text("Randomization & Fallback") }
        }
    }
}

// MARK: - 6. Retry & Recovery (Retry/Requeue + Blank Page + Fallback Chain)

struct DevRetryRecoverySection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Retry & Recovery", settings: $settings) {
            Section {
                devToggle("Requeue On Timeout", $settings.requeueOnTimeout)
                devToggle("Requeue On Connection Failure", $settings.requeueOnConnectionFailure)
                devToggle("Requeue On Red Banner", $settings.requeueOnRedBanner)
                devInt("Max Requeue Count", $settings.maxRequeueCount)
                devInt("Min Attempts Before NoAcc", $settings.minAttemptsBeforeNoAcc)
                devInt("Cycle Pause Min (ms)", $settings.cyclePauseMinMs)
                devInt("Cycle Pause Max (ms)", $settings.cyclePauseMaxMs)
                if settings.cyclePauseMinMs > settings.cyclePauseMaxMs {
                    devValidationWarning("Min cycle pause exceeds Max")
                }
            } header: { Text("Retry / Requeue") }

            Section {
                devToggle("Fallback to Legacy Fill", $settings.fallbackToLegacyFill)
                devToggle("Fallback to OCR Click", $settings.fallbackToOCRClick)
                devToggle("Fallback to Vision ML Click", $settings.fallbackToVisionMLClick)
                devToggle("Fallback to Coordinate Click", $settings.fallbackToCoordinateClick)
                devInfoNote("Fallback chain is tried in order when primary detection fails.")
            } header: { Text("Fallback Chain") }

            Section {
                devToggle("Blank Page Recovery", $settings.blankPageRecoveryEnabled)
                devInt("Blank Page Timeout (s)", $settings.blankPageTimeoutSeconds)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devInt("Blank Page Wait Threshold (s)", $settings.blankPageWaitThresholdSeconds)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
            } header: { Text("Blank Page Detection") }

            Section {
                devToggle("1: Wait & Recheck", $settings.blankPageFallback1_WaitAndRecheck)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devToggle("2: Change URL", $settings.blankPageFallback2_ChangeURL)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devToggle("3: Change DNS", $settings.blankPageFallback3_ChangeDNS)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devToggle("4: Change Fingerprint", $settings.blankPageFallback4_ChangeFingerprint)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devToggle("5: Full Session Reset", $settings.blankPageFallback5_FullSessionReset)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devInt("Max Fallback Attempts", $settings.blankPageMaxFallbackAttempts)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
                devInt("Recheck Interval (ms)", $settings.blankPageRecheckIntervalMs)
                    .disabled(!settings.blankPageRecoveryEnabled)
                    .opacity(settings.blankPageRecoveryEnabled ? 1 : 0.4)
            } header: { Text("Blank Page Fallback Chain") }

            Section {
                devDouble("Page Load Timeout (s)", $settings.pageLoadTimeout)
                devInt("Page Load Retries", $settings.pageLoadRetries)
                devDouble("Retry Backoff Multiplier", $settings.retryBackoffMultiplier)
                devInt("Wait For JS Render (ms)", $settings.waitForJSRenderMs)
                devToggle("Full Session Reset On Final Retry", $settings.fullSessionResetOnFinalRetry)
                devInfoNote("All timeouts have a 180s minimum floor enforced by the engine.")
            } header: { Text("Page Loading") }
        }
    }
}

// MARK: - 7. Security Challenges (MFA + CAPTCHA)

struct DevSecurityChallengesSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Security Challenges", settings: $settings) {
            Section {
                devToggle("MFA Detection", $settings.mfaDetectionEnabled)
                devInt("MFA Wait Timeout (s)", $settings.mfaWaitTimeoutSeconds)
                    .disabled(!settings.mfaDetectionEnabled)
                    .opacity(settings.mfaDetectionEnabled ? 1 : 0.4)
                devToggle("MFA Auto Skip", $settings.mfaAutoSkip)
                    .disabled(!settings.mfaDetectionEnabled)
                    .opacity(settings.mfaDetectionEnabled ? 1 : 0.4)
                devToggle("MFA Mark As Temp Disabled", $settings.mfaMarkAsTempDisabled)
                    .disabled(!settings.mfaDetectionEnabled)
                    .opacity(settings.mfaDetectionEnabled ? 1 : 0.4)
                devStringArray("MFA Keywords", $settings.mfaKeywords)
            } header: { Text("MFA / Two-Factor") }

            Section {
                devToggle("SMS Detection", $settings.smsDetectionEnabled)
                devToggle("SMS Burn Session", $settings.smsBurnSession)
                    .disabled(!settings.smsDetectionEnabled)
                    .opacity(settings.smsDetectionEnabled ? 1 : 0.4)
                devStringArray("SMS Notification Keywords", $settings.smsNotificationKeywords)
                devInfoNote("SMS detection runs independently of MFA detection.")
            } header: { Text("SMS Detection") }

            Section {
                devToggle("CAPTCHA Detection", $settings.captchaDetectionEnabled)
                devToggle("CAPTCHA Auto Skip", $settings.captchaAutoSkip)
                    .disabled(!settings.captchaDetectionEnabled)
                    .opacity(settings.captchaDetectionEnabled ? 1 : 0.4)
                devToggle("CAPTCHA Mark As Failed", $settings.captchaMarkAsFailed)
                    .disabled(!settings.captchaDetectionEnabled)
                    .opacity(settings.captchaDetectionEnabled ? 1 : 0.4)
                devInt("CAPTCHA Wait Timeout (s)", $settings.captchaWaitTimeoutSeconds)
                    .disabled(!settings.captchaDetectionEnabled)
                    .opacity(settings.captchaDetectionEnabled ? 1 : 0.4)
                devStringArray("CAPTCHA Keywords", $settings.captchaKeywords)
                devToggle("CAPTCHA iFrame Detection", $settings.captchaIframeDetection)
                    .disabled(!settings.captchaDetectionEnabled)
                    .opacity(settings.captchaDetectionEnabled ? 1 : 0.4)
                devToggle("CAPTCHA Image Detection", $settings.captchaImageDetection)
                    .disabled(!settings.captchaDetectionEnabled)
                    .opacity(settings.captchaDetectionEnabled ? 1 : 0.4)
            } header: { Text("CAPTCHA") }
        }
    }
}

// MARK: - 8. Fingerprinting & Stealth

struct DevFingerprintingSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Fingerprinting & Stealth", settings: $settings) {
            Section {
                devToggle("Stealth JS Injection", $settings.stealthJSInjection)
                devToggle("Fingerprint Validation", $settings.fingerprintValidationEnabled)
                devToggle("Host Fingerprint Learning", $settings.hostFingerprintLearningEnabled)
                devToggle("Fingerprint Spoofing", $settings.fingerprintSpoofing)
            } header: { Text("Core") }

            Section {
                devToggle("User Agent Rotation", $settings.userAgentRotation)
                devToggle("Viewport Randomization", $settings.viewportRandomization)
                devToggle("WebGL Noise", $settings.webGLNoise)
                devToggle("Canvas Noise", $settings.canvasNoise)
                devToggle("Audio Context Noise", $settings.audioContextNoise)
                devToggle("Timezone Spoof", $settings.timezoneSpoof)
                devToggle("Language Spoof", $settings.languageSpoof)
            } header: { Text("Browser Fingerprint Spoofing") }
        }
    }
}

// MARK: - 9. Session & Cookies

struct DevSessionCookiesSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Session & Cookies", settings: $settings) {
            Section {
                devToggle("Dismiss Cookie Notices", $settings.dismissCookieNotices)
                devInt("Cookie Dismiss Delay (ms)", $settings.cookieDismissDelayMs)
                    .disabled(!settings.dismissCookieNotices)
                    .opacity(settings.dismissCookieNotices ? 1 : 0.4)
            } header: { Text("Cookie / Consent") }

            Section {
                Picker("Session Isolation", selection: $settings.sessionIsolation) {
                    ForEach(AutomationSettings.SessionIsolationMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }.font(.subheadline)
                if settings.sessionIsolation == .full {
                    devInfoNote("Full Isolation overrides all individual clear toggles below to ON.")
                }
                let fullIsolation = settings.sessionIsolation == .full
                devToggle("Clear Cookies Between Attempts", $settings.clearCookiesBetweenAttempts)
                    .disabled(fullIsolation)
                    .opacity(fullIsolation ? 0.4 : 1)
                devToggle("Clear LocalStorage Between Attempts", $settings.clearLocalStorageBetweenAttempts)
                    .disabled(fullIsolation)
                    .opacity(fullIsolation ? 0.4 : 1)
                devToggle("Clear SessionStorage Between Attempts", $settings.clearSessionStorageBetweenAttempts)
                    .disabled(fullIsolation)
                    .opacity(fullIsolation ? 0.4 : 1)
                devToggle("Clear Cache Between Attempts", $settings.clearCacheBetweenAttempts)
                    .disabled(fullIsolation)
                    .opacity(fullIsolation ? 0.4 : 1)
                devToggle("Clear IndexedDB Between Attempts", $settings.clearIndexedDBBetweenAttempts)
                    .disabled(fullIsolation)
                    .opacity(fullIsolation ? 0.4 : 1)
                devToggle("Fresh WebView Per Attempt", $settings.freshWebViewPerAttempt)
            } header: { Text("Session Isolation") }

            Section {
                devInt("WebView Memory Limit (MB)", $settings.webViewMemoryLimitMB)
                devToggle("WebView JS Enabled", $settings.webViewJSEnabled)
                devToggle("WebView Image Loading", $settings.webViewImageLoadingEnabled)
                devToggle("WebView Plugins Enabled", $settings.webViewPluginsEnabled)
            } header: { Text("WebView Configuration") }
        }
    }
}

// MARK: - 10. Concurrency

struct DevConcurrencySection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Concurrency", settings: $settings) {
            Section {
                devInt("Max Concurrency", $settings.maxConcurrency)
                Picker("Concurrency Strategy", selection: $settings.concurrencyStrategy) {
                    ForEach(ConcurrencyStrategy.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }.font(.subheadline)
                devInt("Fixed Pair Count", $settings.fixedPairCount)
                    .disabled(settings.concurrencyStrategy != .fixedPairs)
                    .opacity(settings.concurrencyStrategy == .fixedPairs ? 1 : 0.4)
                devInt("Live User Pair Count", $settings.liveUserPairCount)
                devInt("Batch Delay Between Starts (ms)", $settings.batchDelayBetweenStartsMs)
                devToggle("Connection Test Before Batch", $settings.connectionTestBeforeBatch)
            }
        }
    }
}

// MARK: - 11. Network & Proxy

struct DevNetworkSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Network & Proxy", settings: $settings) {
            Section {
                devToggle("Use Assigned Network For Tests", $settings.useAssignedNetworkForTests)
                devToggle("Proxy Rotate On Disabled", $settings.proxyRotateOnDisabled)
                devToggle("Proxy Rotate On Failure", $settings.proxyRotateOnFailure)
                devToggle("DNS Rotate Per Request", $settings.dnsRotatePerRequest)
                devToggle("VPN Config Rotation", $settings.vpnConfigRotation)
            }
        }
    }
}

// MARK: - 12. URL Management

struct DevURLSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("URL Management", settings: $settings) {
            Section {
                devToggle("URL Rotation Enabled", $settings.urlRotationEnabled)
                devInt("Disable URL After Consecutive Failures", $settings.disableURLAfterConsecutiveFailures)
                    .disabled(!settings.urlRotationEnabled)
                    .opacity(settings.urlRotationEnabled ? 1 : 0.4)
                devDouble("Re-Enable URL After (s)", $settings.reEnableURLAfterSeconds)
                    .disabled(!settings.urlRotationEnabled)
                    .opacity(settings.urlRotationEnabled ? 1 : 0.4)
            } header: { Text("Rotation") }

            Section {
                devToggle("Prefer Fastest URL", $settings.preferFastestURL)
                devToggle("Smart URL Selection", $settings.smartURLSelection)
                if settings.preferFastestURL && settings.smartURLSelection {
                    devInfoNote("Both active — Smart Selection takes priority and uses latency data internally. Fastest URL adds a hard preference for lowest-latency endpoint.")
                }
            } header: { Text("Selection Strategy") }
        }
    }
}

// MARK: - 13. Screenshots & Debug

struct DevScreenshotSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Screenshots & Debug", settings: $settings) {
            Section {
                devToggle("Slow Debug Mode", $settings.slowDebugMode)
                devToggle("Screenshot On Every Eval", $settings.screenshotOnEveryEval)
                devToggle("Screenshot On Failure", $settings.screenshotOnFailure)
                devToggle("Screenshot On Success", $settings.screenshotOnSuccess)
                devInt("Max Screenshot Retention", $settings.maxScreenshotRetention)
            } header: { Text("General") }

            Section {
                Picker("DualFind Screenshots/Attempt", selection: $settings.screenshotsPerAttempt) {
                    ForEach(AutomationSettings.ScreenshotsPerAttempt.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }.font(.subheadline)
                devString("Post Submit Timings (csv)", $settings.postSubmitScreenshotTimings)
                devToggle("Post Submit Screenshots Only", $settings.postSubmitScreenshotsOnly)
            } header: { Text("DualFind Mode") }

            Section {
                Picker("Unified Screenshots/Attempt", selection: $settings.unifiedScreenshotsPerAttempt) {
                    ForEach(AutomationSettings.UnifiedScreenshotCount.allCases, id: \.self) { s in
                        Text(s.label).tag(s)
                    }
                }.font(.subheadline)
                devInt("Unified Post Click Delay (ms)", $settings.unifiedScreenshotPostClickDelayMs)
            } header: { Text("Unified Sessions Mode") }
        }
    }
}

// MARK: - 14. Blacklist & Auto-Actions

struct DevBlacklistSection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("Blacklist & Auto-Actions", settings: $settings) {
            Section {
                devToggle("Auto Blacklist NoAcc", $settings.autoBlacklistNoAcc)
                devToggle("Auto Blacklist Perm Disabled", $settings.autoBlacklistPermDisabled)
                devToggle("Auto Exclude Blacklist", $settings.autoExcludeBlacklist)
            }
        }
    }
}

// MARK: - 15. AI, Viewport & Telemetry

struct DevAITelemetrySection: View {
    @Binding var settings: AutomationSettings
    var body: some View {
        DevSectionPage("AI, Viewport & Telemetry", settings: $settings) {
            Section {
                devToggle("AI Telemetry", $settings.aiTelemetryEnabled)
            } header: { Text("AI") }

            Section {
                devInt("Viewport Width", $settings.viewportWidth)
                devInt("Viewport Height", $settings.viewportHeight)
                if settings.viewportRandomization {
                    devInfoNote("Viewport Randomization is ON in Fingerprinting — these are base values that get randomized.")
                }
                devToggle("Smart Fingerprint Reuse", $settings.smartFingerprintReuse)
                devInt("Viewport Size Variance (px)", $settings.viewportSizeVariancePx)
                devToggle("Mobile Viewport Emulation", $settings.mobileViewportEmulation)
                devDouble("Device Scale Factor", $settings.deviceScaleFactor)
            } header: { Text("Viewport & Window") }
        }
    }
}
