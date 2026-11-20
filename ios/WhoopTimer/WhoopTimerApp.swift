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
    private let accent = Color(red: 0.72, green: 0.97, blue: 0.66)
    private let background = Color(red: 0.035, green: 0.055, blue: 0.06)
    private let presets = [60, 300, 600, 1200]

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var whoop = WhoopController()
    @AppStorage("timerTone") private var toneName = AlarmTone.steady.rawValue
    @AppStorage("playPhoneChime") private var playSound = false
    @AppStorage("ringUntilDismissed") private var untilDismissed = true
    @AppStorage("alarmLimitMinutes") private var limit = 15
    @AppStorage("ringSeconds") private var ringSeconds = 60
    @State private var mode = StartMode.countdown
    @State private var delay = "300"
    @State private var startTime = Date.now.addingTimeInterval(300)
    @State private var showTest = false
    @State private var showTones = false
    @State private var showDetails = false
    @State private var showNativeTest = false
    @State private var attemptedNativeTest = false

    private var tone: AlarmTone {
        let selected = AlarmTone(rawValue: toneName) ?? .steady
        return selected == .burst && !whoop.nativeConfirmed ? .steady : selected
    }
    private var busy: Bool { whoop.activity != .idle }
    private var schedule: TimerStart? {
        switch mode {
        case .countdown:
            guard let seconds = Int(delay), (0...3600).contains(seconds) else { return nil }
            return .countdown(seconds)
        case .scheduled:
            let minute = Calendar.current.dateInterval(of: .minute, for: startTime)?.start ?? startTime
            return minute > .now ? .at(minute) : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                timerFace
                if !whoop.confirmed && !busy { connection }
                if !busy {
                    startSettings
                    soundSettings
                    dismissalSettings
                }
                if !whoop.message.isEmpty {
                    Text(whoop.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tint(accent)
        .safeAreaInset(edge: .bottom) {
            if whoop.confirmed || busy {
                actionBar
            }
        }
        .sheet(isPresented: $showTones, onDismiss: {
            if whoop.activity == .preview || whoop.activity == .nativeTest { whoop.stop() }
            attemptedNativeTest = false
        }) { tones }
        .sheet(isPresented: $showDetails) { details }
        .alert("Send one short vibration?", isPresented: $showTest) {
            Button("Send Test") { whoop.test() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use the iPhone’s existing WHOOP connection. If iOS asks to pair again, cancel the prompt.")
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

    private var header: some View {
        HStack {
            Text("WHOOP Timer")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { showDetails = true } label: {
                Label(whoop.connected ? "Connected" : "Strap",
                      systemImage: whoop.connected ? "link.circle.fill" : "link.circle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(whoop.connected ? accent : .secondary)
        }
    }

    private var timerFace: some View {
        VStack(spacing: 6) {
            Image(systemName: whoop.activity == .vibrating ? "waveform" : "timer")
                .font(.title2.weight(.medium))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text(faceCaption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(faceValue)
                .font(.system(size: 61, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.50)
                .lineLimit(1)
            if whoop.activity == .countdown && mode == .scheduled {
                Text(startTime, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if whoop.activity == .vibrating {
                Text(whoop.listensForTap ? "Try double-tapping the top of your WHOOP, or tap Stop." : "Tap Stop below to dismiss.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            LinearGradient(colors: [Color(red: 0.12, green: 0.22, blue: 0.18), background],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(accent.opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var faceCaption: String {
        switch whoop.activity {
        case .idle: mode == .countdown ? "Countdown" : "Alarm time"
        case .testing: "Sending"
        case .nativeTest: "Testing strap rhythm"
        case .preview: "Previewing"
        case .countdown: "Alarm starts in"
        case .vibrating: untilDismissed ? "Maximum time left" : "Vibration ends in"
        }
    }

    private var faceValue: String {
        switch whoop.activity {
        case .idle: mode == .countdown ? timeString(Int(delay) ?? 0) : startTime.formatted(date: .omitted, time: .shortened)
        case .testing: "Test pulse"
        case .nativeTest: "Native Burst"
        case .preview: tone.rawValue
        case .countdown, .vibrating: timeString(whoop.remaining)
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(whoop.connected ? "Set up vibration" : "Connect your strap").font(.headline)
            if whoop.connected {
                Button(whoop.testAcknowledged ? "I felt it" : "Test Vibration") {
                    if whoop.testAcknowledged { whoop.confirmVibration() } else { showTest = true }
                }
                .buttonStyle(TimerFilledButton(fill: accent))
            } else if whoop.connecting {
                ProgressView("Connecting…")
            } else if whoop.devices.isEmpty {
                Text("Let the official WHOOP app sync, then refresh here.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Refresh") { whoop.refresh() }.buttonStyle(.bordered)
            } else {
                ForEach(whoop.devices, id: \.identifier) { device in
                    Button(whoop.devices.count == 1 ? "Connect WHOOP" : (device.name ?? "WHOOP")) {
                        whoop.connect(device)
                    }
                    .buttonStyle(TimerFilledButton(fill: accent))
                }
            }
        }
        .panel()
    }

    private var startSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Start", selection: $mode) {
                Text("Countdown").tag(StartMode.countdown)
                Text("At a time").tag(StartMode.scheduled)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, mode in
                if mode == .scheduled && startTime <= .now {
                    startTime = .now.addingTimeInterval(300)
                }
            }
            if mode == .countdown {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { seconds in
                        Button("\(seconds / 60) min") { delay = String(seconds) }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Int(delay) == seconds ? accent : .white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Int(delay) == seconds ? Color.black : .primary)
                            .buttonStyle(.plain)
                    }
                }
                LabeledContent("Custom seconds") {
                    TextField("0–3600", text: $delay)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                DatePicker("Start time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
            }
            if schedule == nil {
                Text(mode == .scheduled ? "Choose a future time." : "Enter 0 to 3600 seconds.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .panel()
    }

    private var soundSettings: some View {
        Button { showTones = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform").foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ringtone").font(.headline)
                    Text(tone.rawValue + (playSound ? " · Wrist + iPhone" : " · Wrist only"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .panel()
        }
        .buttonStyle(.plain)
    }

    private var dismissalSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Ring until dismissed", isOn: $untilDismissed).font(.headline)
            if untilDismissed {
                Picker("Maximum ring time", selection: $limit) {
                    ForEach([5, 15, 30, 60], id: \.self) { Text("\($0) min").tag($0) }
                }
                Text(whoop.tapVerified
                     ? "Double-tap detected on this connection."
                     : "Double-tap dismissal needs a strap test. Stop on screen is always available.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Picker("Ring for", selection: $ringSeconds) {
                    Text("30 sec").tag(30)
                    Text("1 min").tag(60)
                    Text("2 min").tag(120)
                    Text("5 min").tag(300)
                }
            }
        }
        .panel()
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            Button {
                if busy {
                    whoop.stop()
                } else if let schedule {
                    whoop.start(schedule: schedule, duration: untilDismissed ? limit * 60 : ringSeconds,
                                tone: tone, playSound: playSound)
                }
            } label: {
                Text(busy ? "Stop" : mode == .countdown ? "Start Timer" : "Arm Alarm")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TimerFilledButton(fill: busy ? Color(red: 1, green: 0.61, blue: 0.59) : accent))
            .disabled(!busy && schedule == nil)
            Text("Keep this app open and your WHOOP connected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var tones: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AlarmTone.allCases) { candidate in
                        Button {
                            if candidate == .burst && !whoop.nativeConfirmed {
                                showNativeTest = true
                            } else {
                                toneName = candidate.rawValue
                                whoop.preview(candidate, playSound: playSound)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.rawValue).font(.headline).foregroundStyle(.primary)
                                    Text(candidate.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if candidate == tone { Image(systemName: "checkmark.circle.fill") }
                            }
                        }
                        .disabled(busy || (candidate == .burst && !whoop.confirmed))
                    }
                    if whoop.nativeAcknowledged && !whoop.nativeConfirmed {
                        Button("I felt a quick burst") {
                            whoop.confirmNativeBurst()
                            toneName = AlarmTone.burst.rawValue
                        }
                    }
                } footer: {
                    Text(whoop.confirmed ? "Tap a ringtone to feel a short preview." : "Connect and test your WHOOP to preview ringtones.")
                }
                if attemptedNativeTest && !whoop.message.isEmpty {
                    Text(whoop.message).font(.footnote).foregroundStyle(.secondary)
                }
                Toggle("Also play sound on iPhone", isOn: $playSound)
                    .disabled(busy)
                if whoop.activity == .preview {
                    Button("Stop Preview", role: .destructive) { whoop.stop() }
                }
            }
            .navigationTitle("Ringtones")
            .alert("Test one native burst?", isPresented: $showNativeTest) {
                Button("Send Test Burst") {
                    attemptedNativeTest = true
                    whoop.testNativeBurst()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("One Bluetooth command asks the strap to repeat its usual vibration quickly. Confirm it only if you feel several pulses.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showTones = false }
                }
            }
        }
    }

    private var details: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    Text(whoop.status)
                    if whoop.connected {
                        Button("Disconnect", role: .destructive) { whoop.disconnect() }
                    }
                    Text(whoop.tapVerified ? "Double-tap detected"
                         : whoop.listensForTap ? "Listening for double-taps. Tap your WHOOP twice to check."
                         : whoop.connected ? "No double-tap notifications on this connection."
                         : "Connect to check double-tap notifications.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !whoop.log.isEmpty {
                    Section("Bluetooth log") {
                        Text(whoop.log.joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Strap")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDetails = false }
                }
            }
        }
    }

    private func timeString(_ value: Int) -> String {
        let seconds = max(0, value)
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct TimerFilledButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(fill.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.55)
    }
}

private extension View {
    func panel() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17))
    }
}
