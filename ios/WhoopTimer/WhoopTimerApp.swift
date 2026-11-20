import CoreBluetooth
import Foundation
import SwiftUI
import UIKit

@main
@MainActor
struct WhoopTimerApp: App {
    var body: some Scene {
        WindowGroup { TimerView() }
    }
}

@MainActor
struct TimerView: View {
    private enum StartMode: Hashable { case countdown, scheduled }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var whoop = WhoopController()
    @State private var startMode = StartMode.countdown
    @State private var startTime = Date.now.addingTimeInterval(300)
    @State private var delay = "30"
    @State private var duration = "60"
    @State private var spacing = "1.5"
    @State private var showTestConfirmation = false
    @State private var showLog = false

    private var busy: Bool { whoop.activity != .idle }

    private var configuration: (TimerStart, Int, Double)? {
        guard let length = Int(duration), (1...300).contains(length),
              let interval = NumberFormatter.localizedNumber(from: spacing) ?? Double(spacing),
              (0.5...10).contains(interval) else { return nil }
        switch startMode {
        case .countdown:
            guard let seconds = Int(delay), (0...3600).contains(seconds) else { return nil }
            return (.countdown(seconds), length, interval)
        case .scheduled:
            let minute = Calendar.current.dateInterval(of: .minute, for: startTime)?.start ?? startTime
            guard minute > .now else { return nil }
            return (.at(minute), length, interval)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(whoop.status)
                        .font(.headline)
                    if !whoop.message.isEmpty {
                        Text(whoop.message).foregroundStyle(.secondary)
                    }
                    if whoop.connected || whoop.connecting {
                        Button("Disconnect") { whoop.disconnect() }
                    } else {
                        ForEach(whoop.devices, id: \.identifier) { device in
                            Button("Connect to \(device.name ?? "WHOOP 5.0")") { whoop.connect(device) }
                        }
                        Button("Refresh") { whoop.refresh() }
                    }
                    if whoop.connected {
                        Button("Test Vibration") { showTestConfirmation = true }
                            .disabled(busy)
                        if whoop.testAcknowledged && !whoop.confirmed {
                            Button("I felt it") { whoop.confirmVibration() }
                        }
                    }
                } header: {
                    Text("Connection")
                }

                Section {
                    if busy {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activityLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if whoop.activity != .testing {
                                Text(timeRemaining)
                                    .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
                                    .accessibilityLabel("\(whoop.remaining) seconds remaining")
                                if startMode == .scheduled && whoop.activity == .countdown {
                                    Text(startTime, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("Stop", role: .destructive) { whoop.stop() }
                    } else {
                        Picker("Start", selection: $startMode) {
                            Text("Countdown").tag(StartMode.countdown)
                            Text("At a time").tag(StartMode.scheduled)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: startMode) { _, mode in
                            if mode == .scheduled && startTime <= .now {
                                startTime = Date.now.addingTimeInterval(300)
                            }
                        }
                        if startMode == .countdown {
                            LabeledContent("Countdown (s)") {
                                TextField("30", text: $delay).keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        } else {
                            DatePicker("Start time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        }
                        LabeledContent("Vibration time (s)") {
                            TextField("60", text: $duration).keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Pulse spacing (s)") {
                            TextField("1.5", text: $spacing).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        if configuration == nil {
                            Text(startMode == .scheduled
                                 ? "Choose a future start time, 1–300 s of vibration, and 0.5–10 s between pulses."
                                 : "Enter 0–3600 s to start, 1–300 s of vibration, and 0.5–10 s between pulses.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button(startMode == .scheduled ? "Arm Alarm" : "Start Timer") {
                            if let (schedule, duration, spacing) = configuration {
                                whoop.start(schedule: schedule, duration: duration, spacing: spacing)
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!whoop.confirmed || configuration == nil)
                    }
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Keep this app on screen. Leaving the app stops the timer.")
                }

                if !whoop.log.isEmpty {
                    Section {
                        DisclosureGroup("Bluetooth log", isExpanded: $showLog) {
                            Text(whoop.log.joined(separator: "\n"))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("WHOOP Timer")
            .scrollDismissesKeyboard(.interactively)
            .alert("Send a short vibration?", isPresented: $showTestConfirmation) {
                Button("Send Test") { whoop.test() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This uses your iPhone’s existing WHOOP connection. If iOS asks to pair again, cancel the prompt and disconnect here.")
            }
            .onChange(of: busy) { _, active in
                UIApplication.shared.isIdleTimerDisabled = active
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    whoop.disconnect()
                    UIApplication.shared.isIdleTimerDisabled = false
                } else if phase == .active {
                    whoop.refresh()
                }
            }
        }
    }

    private var activityLabel: String {
        switch whoop.activity {
        case .idle: "Idle"
        case .testing: "Waiting for the test pulse…"
        case .countdown: "Vibration starts in"
        case .vibrating: "Vibration ends in"
        }
    }

    private var timeRemaining: String {
        let seconds = whoop.remaining
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private extension NumberFormatter {
    static func localizedNumber(from value: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        guard value.allSatisfy({ $0.isNumber || String($0) == formatter.decimalSeparator }),
              !value.isEmpty else { return nil }
        return formatter.number(from: value)?.doubleValue
    }
}
