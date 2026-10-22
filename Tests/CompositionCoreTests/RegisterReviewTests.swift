import Foundation
import XCTest
@testable import CompositionCore

final class RegisterReviewTests: XCTestCase {
    func score(_ pitches: [Double]) -> Score {
        Score(ti: "Register", bpm: 96, ts: .init(n: 4, d: 4), k: "C major", sm: "", tr: [
            Track(nm: "Klavier", ch: 0, pg: 0, nt: pitches.enumerated().map { [Double($0.offset), 1, $0.element, 80, 0, 1] }, ct: [[0, 64, 127]], ev: nil)])
    }
    func data(_ s: Score) throws -> Data { try JSONEncoder().encode(s) }
    func testSustainedExtremeAndPhysicalRangeAreWarnings() throws {
        let safe = try RegisterReview.inspect(scoreJSON: data(score([60, 64, 67])))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: safe) as? [[String: String]], [])
        for pitches: [Double] in [[96, 97, 98], [20], [109]] {
            let issues = try JSONSerialization.jsonObject(with: RegisterReview.inspect(scoreJSON: data(score(pitches)))) as! [[String: Any]]
            XCTAssertEqual(issues.count, 1)
        }
    }
    func testOctaveRepairPreservesCompleteMusic() throws {
        let before = score([60, 100, 103, 108]), after = score([60, 76, 79, 84])
        try RegisterReview.validateRepair(before: data(before), after: data(after), source: "\\score { c'4 }")
        var changed = after
        changed.tr[0].nt[1][2] += 1
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: data(before), after: data(changed), source: ""))
        changed = after; changed.tr[0].nt[1][1] = 2
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: data(before), after: data(changed), source: ""))
        changed = after; changed.tr[0].ct = [[0, 64, 0]]
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: data(before), after: data(changed), source: ""))
        changed = after; changed.tr[0].ch = 1
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: data(before), after: data(changed), source: ""))
    }
    func testUnchangedAndRemainingIssuesReject() throws {
        let before = try data(score([60, 100, 103, 108]))
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: before, after: before, source: ""))
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: before, after: data(score([72, 100, 103, 108])), source: ""))
        XCTAssertThrowsError(try RegisterReview.validateRepair(before: before, after: data(score([60, 76, 79, 84])), source: "\\relative c' { c4 }"))
        // Comments and quoted text do not change the notation mode.
        try RegisterReview.validateRepair(before: before, after: data(score([60, 76, 79, 84])), source: "% \\relative c'\n\\header { title = \"\\relative\" }")
    }
}
