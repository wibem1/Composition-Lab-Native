import Foundation
import XCTest
@testable import CompositionCore

final class MIDIImportRangeTests: XCTestCase {
    func midi(pitch: UInt8) -> Data {
        let events: [UInt8] = [0, 0x90, pitch, 90, 96, 0x80, pitch, 0, 0, 0xff, 0x2f, 0]
        return Data([0x4d,0x54,0x68,0x64,0,0,0,6,0,0,0,1,1,0xe0,
                     0x4d,0x54,0x72,0x6b,0,0,0,UInt8(events.count)] + events)
    }
    func testValidBoundaryPitchesSurviveImport() throws {
        for pitch: UInt8 in [0, 21, 60, 108, 127] {
            let score = try MIDIParser.parse(data: midi(pitch: pitch), fallbackTitle: "Boundary")
            try ScoreValidation.validate(score)
            XCTAssertEqual(score.tr.first?.nt.first?[2], Double(pitch))
        }
    }
    func testLilyPondNegativePitchBytesAreRejectedPrecisely() throws {
        for pitch: UInt8 in [128, 239, 246, 251, 255] {
            XCTAssertThrowsError(try MIDIParser.parse(data: midi(pitch: pitch), fallbackTitle: "Romanze")) { error in
                XCTAssertTrue(error.localizedDescription.contains("Oktavlagen außerhalb MIDI 0–127"))
                XCTAssertTrue(error.localizedDescription.contains("Note \(pitch)"))
            }
        }
    }
}
