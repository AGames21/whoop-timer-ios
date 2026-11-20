import AlarmKit
import Foundation
import SwiftUI

@available(iOS 26.0, *)
@MainActor
enum PhoneAlarm {
    private struct Metadata: AlarmMetadata {}

    private enum SetupError: Error {
        case notAuthorized
        case timePassed
    }

    static func schedule(id: UUID, at date: Date) async throws {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try await manager.requestAuthorization()
        }
        guard manager.authorizationState == .authorized else { throw SetupError.notAuthorized }
        try Task.checkCancellation()
        guard date > .now else { throw SetupError.timePassed }
        let alert = AlarmPresentation.Alert(
            title: "WHOOP Timer backup",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: Metadata(), tintColor: .green
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(date), attributes: attributes, sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    static func exists(id: UUID) throws -> Bool {
        try AlarmManager.shared.alarms.contains { $0.id == id }
    }

    static func cancel(id: UUID) throws {
        if try exists(id: id) {
            try AlarmManager.shared.cancel(id: id)
        }
    }
}
