import Foundation

enum DTCParser {
    /// Parses a mode 03/07/0A response line (e.g. "43 02 02 34 01 71") into
    /// human-readable codes like ["P0234", "P0171"]. Returns [] for "NO DATA"
    /// or a zero-count response.
    static func parse(response: String, expectedEcho: String) -> [String] {
        let hex = response.replacingOccurrences(of: " ", with: "").uppercased()
        guard !hex.contains("NODATA") else { return [] }
        guard hex.hasPrefix(expectedEcho), hex.count >= expectedEcho.count + 2 else { return [] }

        var bytes: [UInt8] = []
        var index = hex.index(hex.startIndex, offsetBy: expectedEcho.count)
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let byte = UInt8(hex[index..<next], radix: 16) else { break }
            bytes.append(byte)
            index = next
        }
        guard !bytes.isEmpty else { return [] }

        // First byte is the DTC count; remaining bytes are 2-byte-per-code pairs.
        let payload = Array(bytes.dropFirst())
        var codes: [String] = []
        var i = 0
        while i + 1 < payload.count {
            let hi = payload[i]
            let lo = payload[i + 1]
            if hi != 0 || lo != 0, let code = decode(hi: hi, lo: lo) {
                codes.append(code)
            }
            i += 2
        }
        return codes
    }

    /// Parses a mode 02 freeze-frame response (e.g. "42 02 00 02 34") into the DTC
    /// that triggered the freeze frame, or nil if no freeze frame is stored.
    static func parseFreezeFrameDTC(response: String) -> String? {
        let hex = response.replacingOccurrences(of: " ", with: "").uppercased()
        guard !hex.contains("NODATA"), hex.hasPrefix("4202"), hex.count >= 10 else { return nil }
        var bytes: [UInt8] = []
        var index = hex.index(hex.startIndex, offsetBy: 4)
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let byte = UInt8(hex[index..<next], radix: 16) else { break }
            bytes.append(byte)
            index = next
        }
        // bytes[0] is the frame number; the DTC occupies the next two bytes.
        guard bytes.count >= 3 else { return nil }
        let hi = bytes[1], lo = bytes[2]
        guard hi != 0 || lo != 0 else { return nil }
        return decode(hi: hi, lo: lo)
    }

    private static func decode(hi: UInt8, lo: UInt8) -> String? {
        let letters = ["P", "C", "B", "U"]
        let letter = letters[Int((hi & 0b1100_0000) >> 6)]
        let digit1 = (hi & 0b0011_0000) >> 4
        let digit2 = hi & 0b0000_1111
        let digit3 = (lo & 0b1111_0000) >> 4
        let digit4 = lo & 0b0000_1111
        return String(format: "%@%X%X%X%X", letter, digit1, digit2, digit3, digit4)
    }
}
