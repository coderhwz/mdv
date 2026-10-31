import AppKit
import XCTest
@testable import MDV

final class SolarizedTests: XCTestCase {
    @MainActor
    func testExistingDocumentFollowsInheritedAppearance() async throws {
        let host = NSView()
        let reader = ReaderTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        reader.backgroundColor = Solarized.background
        host.addSubview(reader)
        let source = "正文\n\n`code`\n\n| 表头 |\n|---|\n| 内容 |"
        let rendered = MarkdownRenderer.render(try AttributedString(markdown: source), baseURL: URL(fileURLWithPath: "/tmp/readme.md"), fontSize: 16)
        reader.textStorage?.setAttributedString(rendered.text)
        let text = try XCTUnwrap(reader.textStorage)
        let foreground = try XCTUnwrap(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        let codeRange = (text.string as NSString).range(of: "code")
        let codeBackground = try XCTUnwrap(text.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil) as? NSColor)
        let headerRange = (text.string as NSString).range(of: "表头")
        let paragraph = try XCTUnwrap(text.attribute(.paragraphStyle, at: headerRange.location, effectiveRange: nil) as? NSParagraphStyle)
        let cell = try XCTUnwrap(paragraph.textBlocks.first as? NSTextTableBlock)
        let tableBackground = try XCTUnwrap(cell.backgroundColor)

        for (mode, background, body, surface) in [
            (NSAppearance.Name.aqua, 0xfdf6e3, 0x657b83, 0xeee8d5),
            (NSAppearance.Name.darkAqua, 0x002b36, 0x839496, 0x073642),
            (NSAppearance.Name.aqua, 0xfdf6e3, 0x657b83, 0xeee8d5)
        ] {
            host.appearance = NSAppearance(named: mode)
            let appearance = reader.effectiveAppearance
            XCTAssertEqual(appearance.bestMatch(from: [.aqua, .darkAqua]), mode)
            appearance.performAsCurrentDrawingAppearance {
                assertRGB(reader.backgroundColor, equals: background)
                assertRGB(foreground, equals: body)
                assertRGB(codeBackground, equals: surface)
                assertRGB(tableBackground, equals: surface)
            }
            XCTAssertTrue(reader.textStorage === text)
            XCTAssertEqual(text.string, rendered.text.string)
        }
    }

    private func assertRGB(_ color: NSColor, equals hex: Int, file: StaticString = #filePath, line: UInt = #line) {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            XCTFail("Cannot resolve color", file: file, line: line)
            return
        }
        XCTAssertEqual(rgb.redComponent, CGFloat((hex >> 16) & 0xff) / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(rgb.greenComponent, CGFloat((hex >> 8) & 0xff) / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(rgb.blueComponent, CGFloat(hex & 0xff) / 255, accuracy: 0.001, file: file, line: line)
    }
}
