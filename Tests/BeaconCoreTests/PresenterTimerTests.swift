import XCTest
@testable import BeaconCore

final class PresenterTimerTests: XCTestCase {
    func testCountsDownAndShowsTime() {
        var t = PresenterTimer()
        t.start(.countdown(300), at: 100)
        XCTAssertEqual(t.display(at: 100), "05:00")
        XCTAssertEqual(t.display(at: 160.4), "04:00")
        XCTAssertEqual(t.display(at: 399), "00:01")
        XCTAssertEqual(t.remaining(at: 200), 200)
    }

    func testPauseHoldsTheTimeAndResumeContinues() {
        var t = PresenterTimer()
        t.start(.countdown(600), at: 0)
        t.pause(at: 100)
        XCTAssertEqual(t.elapsed(at: 5000), 100)
        t.resume(at: 5000)
        XCTAssertEqual(t.elapsed(at: 5050), 150)
        XCTAssertEqual(t.phase, .running)
    }

    func testKeepsCountingPastZeroAsOvertime() {
        var t = PresenterTimer()
        t.start(.countdown(60), at: 0)
        XCTAssertEqual(t.urgency(at: 59), .warning)
        XCTAssertEqual(t.urgency(at: 61), .over)
        XCTAssertEqual(t.display(at: 72), "+00:12")
    }

    func testWarningIsTheLastFifthOrMinute() {
        var t = PresenterTimer()
        t.start(.countdown(3600), at: 0)
        XCTAssertEqual(t.urgency(at: 1000), .normal)
        XCTAssertEqual(t.urgency(at: 2900), .warning, "the last 20 percent is 12 minutes")
        var short = PresenterTimer()
        short.start(.countdown(120), at: 0)
        XCTAssertEqual(short.urgency(at: 70), .warning, "never less than a minute")
        XCTAssertEqual(short.urgency(at: 10), .normal)
    }

    func testStopwatchCountsUpAndFormatsHours() {
        var t = PresenterTimer()
        t.start(.stopwatch, at: 10)
        XCTAssertNil(t.remaining(at: 20))
        XCTAssertEqual(t.display(at: 52), "00:42")
        XCTAssertEqual(t.display(at: 10 + 3905), "1:05:05")
        XCTAssertEqual(t.urgency(at: 5000), .normal)
    }

    func testResetGoesBackToIdle() {
        var t = PresenterTimer()
        t.start(.countdown(300), at: 0)
        t.reset()
        XCTAssertEqual(t.phase, .idle)
        XCTAssertEqual(t.elapsed(at: 999), 0)
    }
}
