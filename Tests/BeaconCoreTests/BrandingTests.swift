import XCTest
@testable import BeaconCore

final class BrandingTests: XCTestCase {
    func testBrandingAppNameIsNotEmpty() {
        XCTAssertFalse(Branding.appName.isEmpty)
        XCTAssertEqual(Branding.appName, "Beacon")
    }
}
