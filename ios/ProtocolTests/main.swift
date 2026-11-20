import Foundation

func bytes(_ hex: String) -> Data {
    Data(hex.split(separator: " ").map { UInt8($0, radix: 16)! })
}

let command = bytes("aa 01 14 00 00 01 e1 e1 23 02 13 01 2f 98 00 00 00 00 00 00 00 00 00 00 e1 a1 fe b4")
precondition(Puffin.buzz(sequence: 2) == command)
let nativeBurst = bytes("aa 01 14 00 00 01 e1 e1 23 02 13 01 2f 98 00 00 00 00 00 00 00 00 02 00 63 c3 c8 86")
precondition(Puffin.buzz(sequence: 2, nativeBurst: true) == nativeBurst)
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

precondition(Puffin.nativeBurstSpacing == 3)
let known = UUID()
let other = UUID()
precondition(WhoopSelection.automatic(from: [known], remembered: nil) == known)
precondition(WhoopSelection.automatic(from: [known, other], remembered: nil) == nil)
precondition(WhoopSelection.automatic(from: [other, known], remembered: known) == known)
precondition(WhoopSelection.automatic(from: [other], remembered: known) == nil)
precondition(WhoopSelection.automatic(from: [], remembered: known) == nil)

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
print("Countdown, scheduling, automatic strap selection, and fresh tap checks passed.")
