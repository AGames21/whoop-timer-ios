import Foundation

enum Puffin {
    static let service = "FD4B0001-CCE1-4033-93CE-002D5875F58A"
    static let write = "FD4B0002-CCE1-4033-93CE-002D5875F58A"
    static let notify = "FD4B0003-CCE1-4033-93CE-002D5875F58A"
    static let hello = Data([0xaa, 1, 8, 0, 0, 1, 0xe6, 0x71,
                             0x23, 1, 0x91, 1, 0x36, 0x3e, 0x5c, 0x8d])
    static let haptic: UInt8 = 0x13

    static func buzz(sequence: UInt8) -> Data {
        let inner: [UInt8] = [35, sequence, haptic, 1, 47, 152] + Array(repeating: 0, count: 10)
        var frame: [UInt8] = [0xaa, 1, 20, 0, 0, 1]
        let headerCRC = crc16(frame)
        frame += [UInt8(truncatingIfNeeded: headerCRC), UInt8(headerCRC >> 8)]
        frame += inner
        let bodyCRC = crc32(inner)
        frame += (0..<4).map { UInt8(truncatingIfNeeded: bodyCRC >> ($0 * 8)) }
        return Data(frame)
    }

    static func crc16(_ bytes: some Sequence<UInt8>) -> UInt16 {
        bytes.reduce(UInt16.max) { previous, byte in
            (0..<8).reduce(previous ^ UInt16(byte)) { crc, _ in
                (crc >> 1) ^ (crc & 1 == 0 ? 0 : 0xa001)
            }
        }
    }

    static func crc32(_ bytes: some Sequence<UInt8>) -> UInt32 {
        ~bytes.reduce(UInt32.max) { previous, byte in
            (0..<8).reduce(previous ^ UInt32(byte)) { crc, _ in
                (crc >> 1) ^ (crc & 1 == 0 ? 0 : 0xedb88320)
            }
        }
    }
}

struct HapticResponses {
    struct Response: Equatable {
        let sequence: UInt8
        let status: UInt8
    }

    private var buffer: [UInt8] = []

    mutating func append(_ value: Data) -> [Response] {
        buffer.append(contentsOf: value)
        var results: [Response] = []
        var offset = 0
        while buffer.count - offset >= 8 {
            let length = Int(buffer[offset + 2]) | Int(buffer[offset + 3]) << 8
            let checksum = UInt16(buffer[offset + 6]) | UInt16(buffer[offset + 7]) << 8
            let start = offset
            guard buffer[start] == 0xaa, buffer[start + 1] == 1, (8...2048).contains(length),
                  checksum == Puffin.crc16(buffer[start..<(start + 6)]) else {
                offset += 1
                continue
            }
            let end = start + 8 + length
            guard end <= buffer.count else { break }
            offset = end
            let tail = end - 4
            let inner = buffer[(start + 8)..<tail]
            guard inner.count >= 5 else { continue }
            let first = inner.startIndex
            guard (inner[first] == 36 || inner[first] == 38), inner[first + 2] == Puffin.haptic else {
                continue
            }
            let expectedCRC = (0..<4).reduce(UInt32(0)) { sum, byte in
                sum | UInt32(buffer[tail + byte]) << (8 * byte)
            }
            guard Puffin.crc32(inner) == expectedCRC else { continue }
            results.append(Response(sequence: inner[first + 3], status: inner[first + 4]))
        }
        buffer.removeFirst(offset)
        return results
    }
}
