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

struct PulseCadence {
    static let testedSpacing: TimeInterval = 1.5

    private(set) var spacing: TimeInterval
    private(set) var nextAt: TimeInterval = 0

    init(spacing: TimeInterval) {
        self.spacing = spacing
    }

    mutating func didSend(at uptime: TimeInterval) {
        nextAt = uptime + spacing
    }

    mutating func slowDown(afterRejectionAt uptime: TimeInterval) -> Bool {
        guard spacing < Self.testedSpacing else { return false }
        spacing = Self.testedSpacing
        nextAt = uptime + spacing
        return true
    }
}
