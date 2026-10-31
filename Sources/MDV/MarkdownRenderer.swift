import AppKit
import ImageIO

struct Heading {
    let title: String
    let level: Int
    let range: NSRange
    let anchor: String
}

struct RenderedDocument {
    let text: NSAttributedString
    let headings: [Heading]
}

/// Foundation parses Markdown; AppKit lays out the resulting semantic blocks.
@MainActor
enum MarkdownRenderer {
    static func render(_ markdown: AttributedString, baseURL: URL, fontSize: CGFloat) -> RenderedDocument {
        let output = NSMutableAttributedString()
        var headings: [Heading] = []
        var previousBlock: Int?
        var blockStart = 0
        var currentHeading: (level: Int, start: Int)?
        var seenListItems = Set<Int>()
        var tables: [Int: NSTextTable] = [:]
        var currentStyle = NSMutableParagraphStyle()
        var blockFont = NSFont.systemFont(ofSize: fontSize)
        var blockColor = Solarized.text
        var codeBlock = false
        var tableHeader = false

        func finishHeading() {
            guard let heading = currentHeading else { return }
            let range = NSRange(location: heading.start, length: output.length - heading.start)
            let title = output.attributedSubstring(from: range).string.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseAnchor = anchor(for: title)
            let duplicates = headings.filter { $0.anchor == baseAnchor || $0.anchor.hasPrefix(baseAnchor + "-") }.count
            headings.append(Heading(title: title, level: heading.level, range: range,
                                    anchor: duplicates == 0 ? baseAnchor : "\(baseAnchor)-\(duplicates)"))
            currentHeading = nil
        }

        for run in markdown.runs {
            let components = run.presentationIntent?.components ?? []
            let block = components.first?.identity ?? -1
            if block != previousBlock {
                finishHeading()
                if output.length > 0, !output.string.hasSuffix("\n") {
                    output.append(NSAttributedString(string: "\n", attributes: [.font: blockFont, .paragraphStyle: currentStyle]))
                }
                previousBlock = block
                blockStart = output.length
                currentStyle = NSMutableParagraphStyle()
                currentStyle.lineSpacing = 5
                currentStyle.paragraphSpacing = 12
                blockFont = .systemFont(ofSize: fontSize)
                blockColor = Solarized.text
                codeBlock = false
                tableHeader = false
                let listDepth = components.filter {
                    switch $0.kind { case .orderedList, .unorderedList: return true; default: return false }
                }.count
                let quoteDepth = components.filter { $0.kind == .blockQuote }.count
                currentStyle.headIndent = CGFloat(listDepth * 22 + quoteDepth * 18)
                currentStyle.firstLineHeadIndent = currentStyle.headIndent
                if quoteDepth > 0 { blockColor = Solarized.muted }

                for component in components {
                    switch component.kind {
                    case .header(let level):
                        blockColor = Solarized.emphasized
                        let sizes: [CGFloat] = [2.0, 1.55, 1.25, 1.1, 1.0, 0.95]
                        blockFont = .systemFont(ofSize: fontSize * sizes[min(max(level - 1, 0), 5)], weight: .bold)
                        currentStyle.paragraphSpacingBefore = level == 1 ? 12 : 18
                        currentStyle.paragraphSpacing = 12
                        currentHeading = (level, blockStart)
                    case .codeBlock:
                        codeBlock = true
                        blockFont = .monospacedSystemFont(ofSize: fontSize * 0.87, weight: .regular)
                        currentStyle.lineSpacing = 3
                        currentStyle.headIndent += 12
                        currentStyle.firstLineHeadIndent = currentStyle.headIndent
                        currentStyle.paragraphSpacing = 4
                    case .tableHeaderRow:
                        tableHeader = true
                    default: break
                    }
                }

                if let tableComponent = components.first(where: { if case .table = $0.kind { return true }; return false }),
                   case .table(let columns) = tableComponent.kind,
                   let cellComponent = components.first(where: { if case .tableCell = $0.kind { return true }; return false }),
                   case .tableCell(let column) = cellComponent.kind {
                    let table = tables[tableComponent.identity] ?? NSTextTable()
                    table.numberOfColumns = columns.count
                    table.collapsesBorders = true
                    tables[tableComponent.identity] = table
                    var row = 0
                    for component in components {
                        if case .tableRow(let index) = component.kind { row = index }
                    }
                    let cell = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
                    cell.setWidth(8, type: .absoluteValueType, for: .padding)
                    cell.setWidth(0.5, type: .absoluteValueType, for: .border)
                    cell.setBorderColor(Solarized.border)
                    cell.backgroundColor = tableHeader ? Solarized.surface : Solarized.background
                    currentStyle.textBlocks = [cell]
                    currentStyle.paragraphSpacing = 0
                    if columns.indices.contains(column) {
                        switch columns[column].alignment {
                        case .left: currentStyle.alignment = .left
                        case .center: currentStyle.alignment = .center
                        case .right: currentStyle.alignment = .right
                        @unknown default: break
                        }
                    }
                }

                if let item = components.first(where: { if case .listItem = $0.kind { return true }; return false }),
                   case .listItem(let ordinal) = item.kind, seenListItems.insert(item.identity).inserted {
                    let parentIndex = components.firstIndex(of: item).map { $0 + 1 }
                    let ordered = parentIndex.map { $0 < components.count && components[$0].kind == .orderedList } ?? false
                    let prefix = ordered ? "\(ordinal).  " : "•  "
                    currentStyle.firstLineHeadIndent = max(0, currentStyle.headIndent - 20)
                    currentStyle.paragraphSpacing = 6
                    output.append(NSAttributedString(string: prefix, attributes: [.font: blockFont, .foregroundColor: blockColor, .paragraphStyle: currentStyle]))
                }
            }

            var font = blockFont
            let intent = run.inlinePresentationIntent ?? []
            if intent.contains(.code) { font = .monospacedSystemFont(ofSize: fontSize * 0.87, weight: .regular) }
            if intent.contains(.stronglyEmphasized) || tableHeader { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
            if intent.contains(.emphasized) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: blockColor, .paragraphStyle: currentStyle]
            if codeBlock || intent.contains(.code) { attributes[.backgroundColor] = Solarized.surface }
            if intent.contains(.code) { attributes[.foregroundColor] = Solarized.cyan }
            if intent.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if let link = run.link { attributes[.link] = URL(string: link.relativeString, relativeTo: baseURL)?.absoluteURL }

            if let imageURL = run.imageURL,
               let resolved = URL(string: imageURL.relativeString, relativeTo: baseURL)?.absoluteURL,
               resolved.isFileURL, let image = thumbnail(at: resolved) {
                let attachment = NSTextAttachment()
                attachment.image = image
                let scale = min(1, 700 / max(1, image.size.width))
                attachment.bounds = NSRect(origin: .zero, size: NSSize(width: image.size.width * scale, height: image.size.height * scale))
                let text = NSMutableAttributedString(attachment: attachment)
                text.addAttributes(attributes, range: NSRange(location: 0, length: text.length))
                output.append(text)
            } else {
                var text = String(markdown[run.range].characters)
                if intent.contains(.lineBreak) { text = "\n" }
                if run.imageURL != nil { text = "[图片：\(text)]" }
                output.append(NSAttributedString(string: text, attributes: attributes))
            }
        }
        finishHeading()
        // NSTextTable requires the final cell to end with a paragraph separator.
        if !currentStyle.textBlocks.isEmpty, !output.string.hasSuffix("\n") {
            output.append(NSAttributedString(string: "\n", attributes: [.font: blockFont, .paragraphStyle: currentStyle]))
        }
        return RenderedDocument(text: output, headings: headings)
    }

    static func anchor(for title: String) -> String {
        title.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "_" }.replacingOccurrences(of: " ", with: "-")
    }

    private static func thumbnail(at url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1400,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
