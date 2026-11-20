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

enum WhoopSelection {
    static func automatic(from available: [UUID], remembered: UUID?) -> UUID? {
        if let remembered { return available.contains(remembered) ? remembered : nil }
        return available.count == 1 ? available.first : nil
    }
}
