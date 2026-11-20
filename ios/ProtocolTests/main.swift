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
