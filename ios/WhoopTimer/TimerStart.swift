import Foundation

enum TimerStart {
    case countdown(Int)
    case at(Date)

    enum Deadline {
        case uptime(TimeInterval)
        case wallClock(Date)

        func remaining(at date: Date, uptime: TimeInterval) -> TimeInterval {
            switch self {
            case .uptime(let end): end - uptime
            case .wallClock(let end): end.timeIntervalSince(date)
            }
        }
    }

    func deadline(at date: Date, uptime: TimeInterval) -> Deadline? {
        switch self {
        case .countdown(let seconds):
            guard (0...3600).contains(seconds) else { return nil }
            return .uptime(uptime + Double(seconds))
        case .at(let time):
            guard time > date else { return nil }
            return .wallClock(time)
        }
    }
}

enum AlarmTone: String, CaseIterable, Identifiable {
    case steady = "Steady"
    case double = "Double"
    case swell = "Swell"
    case burst = "Native Burst"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .steady: "Even pulses · soft chime"
        case .double: "Paired pulses · two-note chime"
        case .swell: "Three spaced pulses · rising chime"
        case .burst: "Quick pulses played by the strap · trial"
        }
    }

    var gaps: [TimeInterval] {
        switch self {
        case .steady: [1.5]
        case .double: [1.2, 2.8]
        case .swell: [1.5, 2, 3]
        case .burst: [3]
        }
    }
}

struct PulseCadence {
    static let testedSpacing: TimeInterval = 1.5

    private let gaps: [TimeInterval]
    private var index = 0
    private var floor: TimeInterval = 1
    private(set) var nextAt: TimeInterval = 0

    init(tone: AlarmTone) {
        gaps = tone.gaps
    }

    mutating func didSend(at uptime: TimeInterval) {
        nextAt = uptime + max(floor, gaps[index])
        index = (index + 1) % gaps.count
    }

    mutating func slowDown(afterRejectionAt uptime: TimeInterval) -> Bool {
        guard floor < Self.testedSpacing, gaps.contains(where: { $0 < Self.testedSpacing }) else { return false }
        floor = Self.testedSpacing
        nextAt = uptime + floor
        return true
    }
}
