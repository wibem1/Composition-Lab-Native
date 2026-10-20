import Foundation
import XCTest
@testable import CompositionCore

final class PlaybackCopyTests: XCTestCase {
    private func original() -> Data {
        let score = Score(ti: "Tempo", bpm: 100, ts: TimeSignature(n: 4, d: 4), k: "C major", sm: "", tr: [Track(nm: "Piano", ch: 0, pg: 0,
            nt: [[0, 1, 60, 80, 0, 1], [1, 1, 64, 100, 0, 1]], ct: [[0, 64, 127]],
            ev: nil, me: [RawMIDIEvent(b: 1, m: "FF 51 03 0B 71 B0", selected: nil, muted: nil)])])
        return MIDIBuilder.build(score)
    }
    func testNeutralSettingsPreserveOriginalBytes() throws {
        let data = original()
        XCTAssertEqual(try PlaybackMIDICopy.make(data, velocityFactor: 1), data)
        XCTAssertEqual(try PlaybackMIDICopy.initialBPM(data), 100, accuracy: 0.001)
    }
    func testVolumeChangesOnlyNoteAttackVelocities() throws {
        let data = original(), copy = try PlaybackMIDICopy.make(data, velocityFactor: 0.5)
        let before = try MIDIParser.parse(data: data, fallbackTitle: "Test")
        let after = try MIDIParser.parse(data: copy, fallbackTitle: "Test")
        XCTAssertEqual(after.tr[0].nt.map { Array($0.prefix(3)) }, before.tr[0].nt.map { Array($0.prefix(3)) })
        XCTAssertEqual(after.tr[0].nt.map { $0[3] }, [40, 50])
        XCTAssertEqual(after.tr[0].ct, before.tr[0].ct)
        XCTAssertEqual(data.count, copy.count)
    }
    func testTempoCopyPreservesTempoMapRatioAndOriginal() throws {
        let data = original(), copy = try PlaybackMIDICopy.make(data, velocityFactor: 1, targetBPM: 200)
        XCTAssertEqual(try PlaybackMIDICopy.initialBPM(copy), 200, accuracy: 0.001)
        // Importer reports the last tempo: both events, 100 and 80, must scale.
        XCTAssertEqual(try MIDIParser.parse(data: copy, fallbackTitle: "Test").bpm, 160, accuracy: 0.001)
        XCTAssertEqual(try PlaybackMIDICopy.initialBPM(data), 100, accuracy: 0.001)
    }
    func testMuteCopyRetainsOriginalAndStopsAllAttacks() throws {
        let data = original()
        let muted = try PlaybackMIDICopy.make(data, velocityFactor: 0)
        XCTAssertNotEqual(data, muted)
        XCTAssertEqual(data.count, muted.count)
        XCTAssertEqual(try MIDIParser.parse(data: data, fallbackTitle: "Original").tr[0].nt.count, 2)
        let changed = zip(data, muted).filter { $0 != $1 }
        XCTAssertEqual(changed.count, 2)
        XCTAssertTrue(changed.allSatisfy { $0.1 == 0 })
    }
    func testInvalidInputsFailWithoutInventingMidi() throws {
        XCTAssertThrowsError(try PlaybackMIDICopy.make(Data(), velocityFactor: 1))
        XCTAssertThrowsError(try PlaybackMIDICopy.make(original(), velocityFactor: .nan))
        XCTAssertThrowsError(try PlaybackMIDICopy.make(original(), velocityFactor: 1, targetBPM: 0))
    }
    func testTempoCanBeAddedWithoutChangingNoteTicks() throws {
        let bytes: [UInt8] = [77,84,104,100,0,0,0,6,0,0,0,1,1,224,77,84,114,107,0,0,0,13,
                             0,144,60,80,131,96,128,60,0,0,255,47,0]
        let original = Data(bytes)
        XCTAssertEqual(try PlaybackMIDICopy.make(original, velocityFactor: 1), original)
        let copy = try PlaybackMIDICopy.make(original, velocityFactor: 1, targetBPM: 100)
        XCTAssertEqual(try PlaybackMIDICopy.initialBPM(copy), 100, accuracy: 0.001)
        let score = try MIDIParser.parse(data: copy, fallbackTitle: "Test")
        XCTAssertEqual(score.tr[0].nt[0][0], 0)
        XCTAssertEqual(score.tr[0].nt[0][1], 1)
        XCTAssertThrowsError(try PlaybackMIDICopy.make(Data(bytes.dropLast()), velocityFactor: 1))
    }

}
