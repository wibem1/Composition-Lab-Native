import Foundation

/// Make a playback-only copy without reconstructing the original MIDI from the
/// simplified interchange score. Event ticks, channels, controllers and note
/// endings remain byte-for-byte intact; only attack velocities and tempi change.
enum PlaybackMIDICopy {
    private struct Tempo { let offset: Int; let tick: Int; let micros: Int }
    private struct Scan { let velocities: [Int]; let tempos: [Tempo]; let firstTrack: Int; let firstTrackLength: Int }
    private static func scan(_ bytes: [UInt8]) throws -> Scan {
        func invalid() -> APIError { .badResponse("Ungültige MIDI-Daten für die Wiedergabekopie.") }
        func u16(_ i: Int) -> Int { Int(bytes[i]) << 8 | Int(bytes[i+1]) }
        func u32(_ i: Int) -> Int { Int(bytes[i]) << 24 | Int(bytes[i+1]) << 16 | Int(bytes[i+2]) << 8 | Int(bytes[i+3]) }
        guard bytes.count >= 14, String(bytes: bytes[0..<4], encoding: .ascii) == "MThd" else { throw invalid() }
        let header = u32(4), count = u16(10)
        guard header >= 6, 8 + header <= bytes.count, count > 0 else { throw invalid() }
        var cursor = 8 + header, velocities: [Int] = [], tempos: [Tempo] = []
        var firstTrack = 0, firstLength = 0
        for track in 0..<count {
            guard cursor + 8 <= bytes.count, String(bytes: bytes[cursor..<cursor+4], encoding: .ascii) == "MTrk" else { throw invalid() }
            let length = u32(cursor + 4), start = cursor + 8, end = start + length
            guard end <= bytes.count else { throw invalid() }
            if track == 0 { firstTrack = start; firstLength = length }
            var pos = start, tick = 0, running: UInt8 = 0
            func vlq() throws -> Int {
                var value = 0
                for _ in 0..<4 {
                    guard pos < end else { throw invalid() }
                    let byte = bytes[pos]; pos += 1; value = value << 7 | Int(byte & 127)
                    if byte & 128 == 0 { return value }
                }
                throw invalid()
            }
            while pos < end {
                tick += try vlq()
                guard pos < end else { throw invalid() }
                let status: UInt8
                if bytes[pos] >= 128 { status = bytes[pos]; pos += 1; if status < 240 { running = status } }
                else { guard running >= 128 else { throw invalid() }; status = running }
                if status == 255 {
                    guard pos < end else { throw invalid() }
                    let type = bytes[pos]; pos += 1
                    let size = try vlq(); guard pos + size <= end else { throw invalid() }
                    if type == 81 && size == 3 {
                        let micros = Int(bytes[pos]) << 16 | Int(bytes[pos+1]) << 8 | Int(bytes[pos+2])
                        guard micros > 0 else { throw invalid() }
                        tempos.append(Tempo(offset: pos, tick: tick, micros: micros))
                    }
                    pos += size
                } else if status == 240 || status == 247 {
                    let size = try vlq(); guard pos + size <= end else { throw invalid() }
                    pos += size; running = 0
                } else {
                    guard status >= 128 && status < 240 else { throw invalid() }
                    let kind = status & 240, size = (kind == 192 || kind == 208) ? 1 : 2
                    guard pos + size <= end, bytes[pos..<pos+size].allSatisfy({ $0 < 128 }) else { throw invalid() }
                    if kind == 144 && bytes[pos+1] > 0 { velocities.append(pos+1) }
                    pos += size
                }
            }
            cursor = end
        }
        return Scan(velocities: velocities, tempos: tempos, firstTrack: firstTrack, firstTrackLength: firstLength)
    }
    static func initialBPM(_ data: Data) throws -> Double {
        let source = try scan(Array(data))
        return source.tempos.first(where: { $0.tick == 0 }).map { 60_000_000 / Double($0.micros) } ?? 120
    }
    static func make(_ original: Data, velocityFactor: Double, targetBPM: Double? = nil) throws -> Data {
        guard velocityFactor.isFinite, velocityFactor > 0, velocityFactor <= 1,
              targetBPM.map({ $0.isFinite && (20...400).contains($0) }) ?? true else { throw APIError.badResponse("Ungültige Player-Einstellungen.") }
        var bytes = Array(original)
        let source = try scan(bytes)
        for offset in source.velocities { bytes[offset] = UInt8(max(1, min(127, Int((Double(bytes[offset]) * velocityFactor).rounded())))) }
        if let targetBPM {
            let initial = source.tempos.first(where: { $0.tick == 0 }).map { 60_000_000 / Double($0.micros) } ?? 120
            let factor = targetBPM / initial
            for tempo in source.tempos {
                let micros = max(1, min(0xFFFFFF, Int((Double(tempo.micros) / factor).rounded())))
                bytes[tempo.offset] = UInt8((micros >> 16) & 255); bytes[tempo.offset+1] = UInt8((micros >> 8) & 255); bytes[tempo.offset+2] = UInt8(micros & 255)
            }
            if !source.tempos.contains(where: { $0.tick == 0 }) {
                let micros = Int((60_000_000 / targetBPM).rounded())
                bytes.insert(contentsOf: [0, 255, 81, 3, UInt8((micros >> 16) & 255), UInt8((micros >> 8) & 255), UInt8(micros & 255)], at: source.firstTrack)
                let length = source.firstTrackLength + 7, index = source.firstTrack - 4
                for byte in 0..<4 { bytes[index+byte] = UInt8((length >> (24 - byte * 8)) & 255) }
            }
        }
        return Data(bytes)
    }
}
