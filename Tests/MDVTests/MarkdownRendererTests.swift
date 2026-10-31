import AppKit
import XCTest
@testable import MDV

final class MarkdownRendererTests: XCTestCase {
    @MainActor
    func testSemanticHeadingsAndUnicodeRanges() async throws {
        let source = "# 中文 🐈 **标题**\n\n段落\n\n```md\n# 不是标题\n```\n\n## 第二节\n\n## 第二节"
        let result = MarkdownRenderer.render(try AttributedString(markdown: source), baseURL: URL(fileURLWithPath: "/tmp/readme.md"), fontSize: 16)
        XCTAssertEqual(result.headings.map(\.level), [1, 2, 2])
        XCTAssertEqual(result.headings.map(\.title), ["中文 🐈 标题", "第二节", "第二节"])
        XCTAssertEqual(result.headings.map(\.anchor).suffix(2), ["第二节", "第二节-1"])
        for heading in result.headings {
            XCTAssertEqual(result.text.attributedSubstring(from: heading.range).string, heading.title)
        }
        XCTAssertTrue(result.text.string.contains("# 不是标题"))
    }

    @MainActor
    func testTableUsesNativeCellsAndPreservesLastCell() async throws {
        let result = MarkdownRenderer.render(try AttributedString(markdown: "| A | B |\n|---|---:|\n| x | y |"), baseURL: URL(fileURLWithPath: "/tmp/readme.md"), fontSize: 16)
        XCTAssertEqual(result.text.string, "A\nB\nx\ny\n")
        let style = try XCTUnwrap(result.text.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle)
        let cell = try XCTUnwrap(style.textBlocks.first as? NSTextTableBlock)
        XCTAssertEqual(cell.startingColumn, 1)
        XCTAssertEqual(cell.startingRow, 1)
        XCTAssertEqual(style.alignment, .right)
    }

    @MainActor
    func testRelativeLinksListsAndEmphasis() async throws {
        let source = "[章节](#章节) 和 [下篇](next.md)\n\n1. **第一项**\n2. 第二项\n   - 子项"
        let result = MarkdownRenderer.render(try AttributedString(markdown: source), baseURL: URL(fileURLWithPath: "/tmp/docs/readme.md"), fontSize: 16)
        let link = result.text.attribute(.link, at: 0, effectiveRange: nil) as? URL
        XCTAssertEqual(link?.absoluteString, "file:///tmp/docs/readme.md#%E7%AB%A0%E8%8A%82")
        let nextRange = (result.text.string as NSString).range(of: "下篇")
        let next = result.text.attribute(.link, at: nextRange.location, effectiveRange: nil) as? URL
        XCTAssertEqual(next?.path, "/tmp/docs/next.md")
        XCTAssertTrue(result.text.string.contains("1.  第一项"))
        XCTAssertTrue(result.text.string.contains("2.  第二项"))
        XCTAssertTrue(result.text.string.contains("•  子项"))
        let bold = (result.text.string as NSString).range(of: "第一项")
        let font = try XCTUnwrap(result.text.attribute(.font, at: bold.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }
}
