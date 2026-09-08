import Foundation

enum MIDIBuilder {
    static let ppq = 480

    static func build(_ score: Score, endPaddingSeconds: Double = 0) -> Data {
        var chunks = [Data]()
        var header = Data("MThd".utf8)
        header.append(contentsOf: be32(6))
        header.append(contentsOf: be16(1))
        header.append(contentsOf: be16(UInt16(score.tr.count + 1)))
        header.append(contentsOf: be16(UInt16(ppq)))
        chunks.append(header)

        var metaEvents: [(Int,[UInt8])] = []
        let tempo = max(20.0, min(300.0, score.bpm))
        let mpqn = Int((60_000_000.0 / tempo).rounded())
        metaEvents.append((0, [0xff,0x51,0x03, UInt8((mpqn>>16)&255), UInt8((mpqn>>8)&255), UInt8(mpqn&255)]))
        let dd = UInt8(max(0, Int(log2(Double(max(1, score.ts.d))))))
        metaEvents.append((0, [0xff,0x58,0x04, UInt8(clamping: score.ts.n), dd, 24, 8]))
        let title = Array(score.ti.utf8)
        metaEvents.append((0, [0xff,0x03] + vlq(title.count) + title))
        chunks.append(trackChunk(metaEvents))

        for track in score.tr {
            var events: [(Int,[UInt8],Int)] = []
            let ch = UInt8(max(0,min(15,track.ch)))
            let pg = UInt8(max(0,min(127,track.pg)))
            let name = Array(track.nm.utf8)
            events.append((0, [0xff,0x03] + vlq(name.count) + name, 0))
            events.append((0, [0xC0 | ch, pg], 1))

            for n in track.nt where n.count >= 4 {
                let start = max(0, n[0])
                let dur = max(0.001, n[1])
                let pitch = UInt8(max(0,min(127,Int(n[2]))))
                let vel = UInt8(max(1,min(127,Int(n[3]))))
                let gate = n.count > 5 ? max(0.01,n[5]) : 0.95
                let on = Int((start * Double(ppq)).rounded())
                let off = Int(((start + dur * gate) * Double(ppq)).rounded())
                events.append((on, [0x90 | ch, pitch, vel], 2))
                events.append((off, [0x80 | ch, pitch, 0], 0))
            }

            let semanticPedal = (track.ev ?? []).filter { $0.t.lowercased() == "pedal" }

            // Legacy-Controller bleiben erhalten. CC64 wird jedoch ignoriert,
            // sobald die neue semantische Pedalnotation vorhanden ist.
            for c in track.ct ?? [] where c.count >= 3 {
                let beat = max(0,c[0])
                let ccInt = max(0,min(127,Int(c[1])))
                if ccInt == 64 && !semanticPedal.isEmpty { continue }
                let cc = UInt8(ccInt)
                let val = UInt8(max(0,min(127,Int(c[2]))))
                events.append((Int((beat * Double(ppq)).rounded()), [0xB0 | ch, cc, val], 1))
            }

            // Rohe Nicht-Noten-MIDI-Ereignisse aus DAW-Roundtrips.
            // Note-On/Off werden absichtlich nicht aus `me` übernommen, da `nt` die Notenquelle ist.
            for raw in track.me ?? [] {
                let parts = raw.m.split(separator: " ")
                let bytes = parts.compactMap { UInt8($0, radix: 16) }
                guard let status = bytes.first, status >= 0x80 else { continue }
                let kind = status & 0xF0
                if kind == 0x80 || kind == 0x90 { continue }
                let tick = Int((max(0, raw.b) * Double(ppq)).rounded())
                events.append((tick, bytes, 1))
            }

            // Semantisches Pedal -> CC64 für die hörbare MIDI-Ausgabe.
            // "change" bedeutet: am selben Tick lösen und unmittelbar neu nehmen.
            for ev in semanticPedal.sorted(by: { $0.b < $1.b }) {
                let tick = Int((max(0, ev.b) * Double(ppq)).rounded())
                switch ev.v?.lowercased() {
                case "start":
                    events.append((tick, [0xB0 | ch, 64, 127], 1))
                case "change":
                    events.append((tick, [0xB0 | ch, 64, 0], 0))
                    events.append((tick, [0xB0 | ch, 64, 127], 1))
                case "stop":
                    events.append((tick, [0xB0 | ch, 64, 0], 0))
                default:
                    break
                }
            }

            events.sort {
                if $0.0 != $1.0 { return $0.0 < $1.0 }
                return $0.2 < $1.2
            }
            let paddingTicks: Int
            if endPaddingSeconds > 0 {
                let beats = endPaddingSeconds * tempo / 60.0
                paddingTicks = max(0, Int((beats * Double(ppq)).rounded()))
            } else {
                paddingTicks = 0
            }
            chunks.append(trackChunk(events.map { ($0.0,$0.1) }, endPaddingTicks: paddingTicks))
        }
        return chunks.reduce(into: Data()) { $0.append($1) }
    }

    private static func trackChunk(_ events: [(Int,[UInt8])], endPaddingTicks: Int = 0) -> Data {
        var body = Data()
        var last = 0
        for (time, bytes) in events {
            body.append(contentsOf: vlq(max(0,time-last)))
            body.append(contentsOf: bytes)
            last = time
        }
        // Für die Player-Version kann das Track-Ende bewusst nach hinten gelegt werden.
        // Dadurch darf der Synthesizer nach dem letzten Note-Off natürlich ausklingen.
        body.append(contentsOf: vlq(max(0, endPaddingTicks)))
        body.append(contentsOf: [0xff,0x2f,0x00])
        var out = Data("MTrk".utf8)
        out.append(contentsOf: be32(UInt32(body.count)))
        out.append(body)
        return out
    }

    private static func vlq(_ value: Int) -> [UInt8] {
        var value = max(0, value)
        var bytes: [UInt8] = [UInt8(value & 0x7f)]
        value >>= 7

        while value > 0 {
            bytes.insert(UInt8((value & 0x7f) | 0x80), at: 0)
            value >>= 7
        }
        return bytes
    }

    private static func be16(_ n: UInt16) -> [UInt8] {
        [UInt8((n>>8)&255), UInt8(n&255)]
    }
    private static func be32(_ n: UInt32) -> [UInt8] {
        [UInt8((n>>24)&255),UInt8((n>>16)&255),UInt8((n>>8)&255),UInt8(n&255)]
    }
}
