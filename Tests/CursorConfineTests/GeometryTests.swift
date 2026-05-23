import XCTest
import CoreGraphics
@testable import CursorConfine

final class GeometryTests: XCTestCase {

    func testClampInsideReturnsSamePoint() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let p = CGPoint(x: 150, y: 150)
        XCTAssertEqual(Geometry.clamp(point: p, to: rect), p)
    }

    func testClampPointToLeftEdge() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let p = CGPoint(x: 50, y: 150)
        XCTAssertEqual(Geometry.clamp(point: p, to: rect), CGPoint(x: 100, y: 150))
    }

    func testClampPointToRightEdge_StaysOnLastInBoundsPixel() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let p = CGPoint(x: 500, y: 150)
        // maxX is 300 (exclusive); cursor should sit at 299.
        XCTAssertEqual(Geometry.clamp(point: p, to: rect), CGPoint(x: 299, y: 150))
    }

    func testClampPointToTopAndBottomEdges() {
        let rect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(
            Geometry.clamp(point: CGPoint(x: 500, y: -10), to: rect),
            CGPoint(x: 500, y: 0)
        )
        XCTAssertEqual(
            Geometry.clamp(point: CGPoint(x: 500, y: 10_000), to: rect),
            CGPoint(x: 500, y: 1079)
        )
    }

    func testClampToEmptyRectIsNoOp() {
        let rect = CGRect.zero
        let p = CGPoint(x: 123, y: 456)
        XCTAssertEqual(Geometry.clamp(point: p, to: rect), p)
    }

    func testClampToInvertedRectIsNoOp() {
        let rect = CGRect(x: 0, y: 0, width: -10, height: -10)
        let p = CGPoint(x: 5, y: 5)
        XCTAssertEqual(Geometry.clamp(point: p, to: rect), p)
    }

    func testInsettingShrinks() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let r = Geometry.insetting(rect, by: 10)
        XCTAssertEqual(r, CGRect(x: 110, y: 110, width: 180, height: 180))
    }

    func testInsettingDoesNotCollapse() {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        let r = Geometry.insetting(rect, by: 100)
        XCTAssertEqual(r, rect)
    }

    func testInsetByZeroIsNoOp() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 200)
        XCTAssertEqual(Geometry.insetting(rect, by: 0), rect)
    }

    func testClampOneByOnePoint() {
        // 1x1 rect: only legal coord is (x,y). Clamp anything to it.
        let rect = CGRect(x: 50, y: 60, width: 1, height: 1)
        let p = CGPoint(x: 999, y: 999)
        XCTAssertEqual(Geometry.clamp(point: p, to: rect), CGPoint(x: 50, y: 60))
    }
}
