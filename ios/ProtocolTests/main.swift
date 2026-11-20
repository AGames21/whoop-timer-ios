import Foundation

func bytes(_ hex: String) -> Data {
    Data(hex.split(separator: " ").map { UInt8($0, radix: 16)! })
}

let command = bytes("aa 01 14 00 00 01 e1 e1 23 02 13 01 2f 98 00 00 00 00 00 00 00 00 00 00 e1 a1 fe b4")
precondition(Puffin.buzz(sequence: 2) == command)
let pending = bytes("aa 01 0c 00 01 00 27 11 24 02 13 02 02 01 01 00 44 12 d3 c2")
let success = bytes("aa 01 0c 00 01 00 27 11 24 03 13 02 01 01 05 00 1a 73 7d 12")
var damaged = success
damaged[damaged.count - 1] ^= 1
var parser = HapticResponses()
precondition(parser.append(bytes("00 ff aa") + pending.prefix(10)).isEmpty)
precondition(parser.append(Data(pending.dropFirst(10)) + damaged + success) == [
    .init(sequence: 2, status: 2), .init(sequence: 2, status: 1)
])
print("WHOOP 5.0 command and response fixtures passed.")

let date = Date(timeIntervalSince1970: 10_000)
let countdown = TimerStart.countdown(30).deadline(at: date, uptime: 20)!
precondition(countdown.remaining(at: date.addingTimeInterval(180), uptime: 35) == 15)
let scheduled = TimerStart.at(date.addingTimeInterval(120)).deadline(at: date, uptime: 20)!
precondition(scheduled.remaining(at: date.addingTimeInterval(119), uptime: 400) == 1)
precondition(scheduled.remaining(at: date.addingTimeInterval(120), uptime: 401) == 0)
precondition(TimerStart.at(date).deadline(at: date, uptime: 20) == nil)
precondition(TimerStart.countdown(-1).deadline(at: date, uptime: 20) == nil)

precondition(AlarmTone.allCases.allSatisfy { $0.gaps.allSatisfy { $0 >= 1 } })
var cadence = PulseCadence(tone: .double)
cadence.didSend(at: 10)
precondition(abs(cadence.nextAt - 11.2) < 0.0001)
precondition(cadence.slowDown(afterRejectionAt: 10.1))
precondition(abs(cadence.nextAt - 11.6) < 0.0001)
cadence.didSend(at: 11.6)
precondition(abs(cadence.nextAt - 14.4) < 0.0001)
cadence.didSend(at: 14.4)
precondition(abs(cadence.nextAt - 15.9) < 0.0001)
precondition(!cadence.slowDown(afterRejectionAt: 11.7))

let tapInner: [UInt8] = [48, 7, 14, 0, 0, 75, 230, 104]
var eventStream = PuffinFrames()
let tapFrame = bytes("aa 01 0c 00 01 00 27 11 30 07 0e 00 00 4b e6 68 cb 0c c0 28")
precondition(eventStream.append(tapFrame.prefix(9)).isEmpty)
precondition(eventStream.append(Data(tapFrame.dropFirst(9))) == [tapInner])
let tap = Puffin.doubleTapTimestamp(tapInner)!
precondition(Puffin.isLiveTap(tap, now: tap + 3, ringingSince: tap - 1))
precondition(!Puffin.isLiveTap(tap, now: tap + 3, ringingSince: tap + 1))
precondition(!Puffin.isLiveTap(tap, now: tap + 11, ringingSince: nil))
precondition(Puffin.doubleTapTimestamp([54, 7, 14, 0, 0, 75, 230, 104]) == nil)
precondition(Puffin.doubleTapTimestamp([48, 7, 14, 0]) == nil)
print("Countdown, scheduling, ringtone timing, and fresh tap checks passed.")
