import XCTest
@testable import CursorlightCore

final class BrandingTests: XCTestCase {
    func testBrandingAppNameIsNotEmpty() {
        XCTAssertFalse(Branding.appName.isEmpty)
        XCTAssertEqual(Branding.appName, "Cursorlight")
    }
}
