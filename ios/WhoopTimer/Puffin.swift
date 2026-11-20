import Foundation

enum Puffin {
    static let service = "FD4B0001-CCE1-4033-93CE-002D5875F58A"
    static let write = "FD4B0002-CCE1-4033-93CE-002D5875F58A"
    static let notify = "FD4B0003-CCE1-4033-93CE-002D5875F58A"
    static let events = "FD4B0004-CCE1-4033-93CE-002D5875F58A"
    static let hello = Data([0xaa, 1, 8, 0, 0, 1, 0xe6, 0x71,
                             0x23, 1, 0x91, 1, 0x36, 0x3e, 0x5c, 0x8d])
    static let haptic: UInt8 = 0x13
    static let nativeBurstSpacing: TimeInterval = 3

    static func buzz(sequence: UInt8, nativeBurst: Bool = false) -> Data {
        // The last body byte requests repeat effects on the strap. The second byte here is frame padding.
        let tail: [UInt8] = [nativeBurst ? 2 : 0, 0]
        let inner: [UInt8] = [35, sequence, haptic, 1, 47, 152] + Array(repeating: 0, count: 8) + tail
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

    static func doubleTapTimestamp(_ inner: [UInt8]) -> TimeInterval? {
        // Type 54 carries the battery pack's event vocabulary. Only type 48 is a strap tap.
        guard inner.count >= 8, inner[0] == 48, inner[2] == 14 else { return nil }
        let seconds = (0..<4).reduce(UInt32(0)) { value, offset in
            value | UInt32(inner[4 + offset]) << (8 * offset)
        }
        return seconds > 0 ? TimeInterval(seconds) : nil
    }

    static func isLiveTap(_ timestamp: TimeInterval, now: TimeInterval, ringingSince: TimeInterval?) -> Bool {
        abs(now - timestamp) <= 10 && (ringingSince.map { timestamp >= floor($0) } ?? true)
    }
}

struct HapticResponses {
    struct Response: Equatable {
        let sequence: UInt8
        let status: UInt8
    }

    private var frames = PuffinFrames()

    mutating func append(_ value: Data) -> [Response] {
        frames.append(value).compactMap { inner in
            guard inner.count >= 5, (inner[0] == 36 || inner[0] == 38), inner[2] == Puffin.haptic else {
                return nil
            }
            return Response(sequence: inner[3], status: inner[4])
        }
    }
}

struct PuffinFrames {
    private var buffer: [UInt8] = []

    mutating func append(_ value: Data) -> [[UInt8]] {
        buffer.append(contentsOf: value)
        var results: [[UInt8]] = []
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
            let expectedCRC = (0..<4).reduce(UInt32(0)) { sum, byte in
                sum | UInt32(buffer[tail + byte]) << (8 * byte)
            }
            guard Puffin.crc32(inner) == expectedCRC else { continue }
            results.append(Array(inner))
        }
        buffer.removeFirst(offset)
        return results
    }
}
