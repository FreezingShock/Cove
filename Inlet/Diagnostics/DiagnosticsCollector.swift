//
//  DiagnosticsCollector.swift
//  Inlet
//
//  Receives MetricKit diagnostic reports (crashes, hangs, CPU and disk
//  exceptions) and saves them on this Mac. Off unless the user opts in.
//
//  MetricKit delivers a crash report on the next launch after the crash,
//  so a report can arrive a day late. Reports contain symbolicated call
//  stacks and system details, not your files.
//

import Foundation
import MetricKit
import OSLog

final class DiagnosticsCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = DiagnosticsCollector()

    /// UserDefaults key for the opt-in. Off by default.
    /// The Privacy pane's toggle writes this key (see InletSettings).
    static let enabledKey = InletSettings.Key.diagnosticsEnabled.rawValue

    private let log = Logger(subsystem: "com.freezingshock.Inlet", category: "Diagnostics")
    private var isSubscribed = false

    override init() {
        super.init()
    }

    /// Whether the user has turned crash reporting on.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Subscribes to MetricKit only when the user has opted in.
    /// Call once at launch. Safe to call when the user has not opted in.
    func startIfEnabled() {
        guard Self.isEnabled else { return }
        start()
    }

    /// Subscribes to MetricKit. Reports begin to arrive after this call.
    func start() {
        guard !isSubscribed else { return }
        MXMetricManager.shared.add(self)
        isSubscribed = true
        log.info("Crash reporting started")
    }

    /// Unsubscribes from MetricKit. Reports already saved stay on disk
    /// until the user erases them.
    func stop() {
        guard isSubscribed else { return }
        MXMetricManager.shared.remove(self)
        isSubscribed = false
        log.info("Crash reporting stopped")
    }

    // MARK: MXMetricManagerSubscriber

    /// Called on a background queue when new diagnostics are ready.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard Self.isEnabled else { return }

        for payload in payloads {
            let metadata = StoredDiagnostic(
                id: UUID(),
                receivedAt: Date(),
                periodStart: payload.timeStampBegin,
                periodEnd: payload.timeStampEnd,
                crashCount: payload.crashDiagnostics?.count ?? 0,
                hangCount: payload.hangDiagnostics?.count ?? 0,
                cpuExceptionCount: payload.cpuExceptionDiagnostics?.count ?? 0,
                diskWriteExceptionCount: payload.diskWriteExceptionDiagnostics?.count ?? 0,
                appVersion: Bundle.main.appVersionString,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString
            )

            // Skip empty payloads so the list only shows real problems.
            guard metadata.problemCount > 0 else { continue }

            DiagnosticStore.shared.save(json: payload.jsonRepresentation(), metadata: metadata)
        }
    }

    /// Daily metric payloads. Inlet doesn't use them, so they are ignored.
    func didReceive(_ payloads: [MXMetricPayload]) {}
}
