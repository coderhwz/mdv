import AppKit
import UniformTypeIdentifiers

private extension NSToolbarItem.Identifier {
    static let open = Self("open")
    static let outline = Self("outline")
    static let smaller = Self("smaller")
    static let larger = Self("larger")
    static let find = Self("find")
}

@MainActor
final class ReaderWindowController: NSWindowController, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
    private let split = NSSplitViewController()
    private let outline = NSTableView()
    private let textView = ReaderTextView()
    private let scroll = NSScrollView()
    private let status = NSTextField(labelWithString: "只读 · 原生 Markdown 查看器")
    private let outlineEmpty = NSTextField(wrappingLabelWithString: "打开 Markdown 文件后，\n这里会显示文章标题。")
    private let welcome = NSStackView()
    private let progress = NSProgressIndicator()
    private var sidebarItem: NSSplitViewItem!
    private var headings: [Heading] = []
    private var fileURL: URL?
    private var loading: Task<Void, Never>?
    private var fontSize: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "fontSize")
        return saved == 0 ? 16 : min(28, max(12, saved))
    }()
    private var selectingHeading = false

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 780),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "MDV"
        window.subtitle = "轻轻打开，静静阅读"
        window.backgroundColor = Solarized.background
        window.minSize = NSSize(width: 720, height: 480)
        window.isReleasedWhenClosed = false
        window.contentViewController = split
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "ReaderToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        buildSidebar()
        buildReader()
        window.setContentSize(NSSize(width: 1100, height: 740))
        split.splitView.setPosition(240, ofDividerAt: 0)
        window.center()
        window.setFrameAutosaveName("ReaderWindow")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildSidebar() {
        let controller = NSViewController()
        let background = SolarizedBackgroundView()
        background.fillColor = Solarized.surface
        controller.view = background
        let title = NSTextField(labelWithString: "文章目录")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = Solarized.text
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("heading"))
        outline.addTableColumn(column)
        outline.headerView = nil
        outline.style = .sourceList
        outline.backgroundColor = .clear
        outline.focusRingType = .none
        outline.rowHeight = 34
        outline.intercellSpacing = NSSize(width: 0, height: 2)
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.action = #selector(jumpToHeading)
        let outlineScroll = NSScrollView()
        outlineScroll.documentView = outline
        outlineScroll.hasVerticalScroller = true
        outlineScroll.drawsBackground = false
        outlineEmpty.font = .systemFont(ofSize: 12)
        outlineEmpty.textColor = Solarized.muted
        for view in [title, outlineScroll, outlineEmpty] {
            view.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(view)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            title.topAnchor.constraint(equalTo: background.topAnchor, constant: 22),
            outlineScroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            outlineScroll.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 8),
            outlineScroll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -8),
            outlineScroll.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12),
            outlineEmpty.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            outlineEmpty.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            outlineEmpty.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16)
        ])
        sidebarItem = NSSplitViewItem(sidebarWithViewController: controller)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 340
        sidebarItem.canCollapse = true
        split.addSplitViewItem(sidebarItem)
        split.splitView.setPosition(240, ofDividerAt: 0)
    }

    private func buildReader() {
        let controller = NSViewController()
        controller.view = SolarizedBackgroundView()
        let view = controller.view
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.delegate = self
        textView.drawsBackground = true
        textView.backgroundColor = Solarized.background
        textView.textColor = Solarized.text
        textView.selectedTextAttributes = [.backgroundColor: Solarized.surface, .foregroundColor: Solarized.emphasized]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.textContainer?.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
        textView.linkTextAttributes = [.foregroundColor: Solarized.blue, .cursor: NSCursor.pointingHand]
        textView.openFile = { [weak self] in self?.open($0) }
        textView.registerForDraggedTypes([.fileURL])
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        status.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        status.textColor = Solarized.text
        status.lineBreakMode = .byTruncatingMiddle
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        let line = NSBox(); line.boxType = .separator
        for child in [scroll, status, progress, line] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: line.topAnchor),
            line.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            status.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: -15),
            status.trailingAnchor.constraint(lessThanOrEqualTo: progress.leadingAnchor, constant: -12),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            progress.centerYAnchor.constraint(equalTo: status.centerYAnchor)
        ])
        welcome.orientation = .vertical
        welcome.alignment = .centerX
        welcome.spacing = 16
        let icon = NSImageView(image: NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)!)
        icon.contentTintColor = Solarized.muted
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 52, weight: .ultraLight)
        let title = NSTextField(labelWithString: "留一点空间，给阅读。")
        title.font = .systemFont(ofSize: 25, weight: .medium)
        title.textColor = Solarized.emphasized
        let hint = NSTextField(labelWithString: "拖入 Markdown 文件，或按 ⌘O 打开")
        hint.font = .systemFont(ofSize: 13)
        hint.textColor = Solarized.text
        let button = NSButton(title: "打开 Markdown…", target: self, action: #selector(openFromToolbar))
        button.bezelStyle = .rounded
        for child in [icon, title, hint, button] { welcome.addArrangedSubview(child) }
        welcome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(welcome)
        NSLayoutConstraint.activate([
            welcome.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            welcome.centerYAnchor.constraint(equalTo: scroll.centerYAnchor, constant: -24)
        ])
        split.addSplitViewItem(NSSplitViewItem(viewController: controller))
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let url = panel.url { self?.open(url) }
        }
    }

    func open(_ url: URL) {
        loading?.cancel()
        progress.startAnimation(nil)
        status.stringValue = "正在打开 \(url.lastPathComponent)…"
        let size = fontSize
        loading = Task { [weak self] in
            do {
                let parsed = try await Task.detached(priority: .userInitiated) {
                    let source = try String(contentsOf: url, encoding: .utf8)
                    try Task.checkCancellation()
                    return try AttributedString(markdown: source, options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible))
                }.value
                try Task.checkCancellation()
                guard let self else { return }
                let rendered = MarkdownRenderer.render(parsed, baseURL: url, fontSize: size)
                let oldScroll = self.fileURL == url ? self.scroll.contentView.bounds.origin : .zero
                self.selectingHeading = true
                self.textView.textStorage?.setAttributedString(rendered.text)
                self.textView.resizeImages(force: true)
                self.headings = rendered.headings
                self.outline.reloadData()
                self.outline.deselectAll(nil)
                self.outlineEmpty.stringValue = "这篇文章没有标题。\n使用 # 标题可生成目录。"
                self.outlineEmpty.isHidden = !self.headings.isEmpty
                self.fileURL = url
                self.welcome.isHidden = true
                self.window?.title = url.lastPathComponent
                self.window?.subtitle = url.deletingLastPathComponent().path
                self.window?.representedURL = url
                self.window?.makeFirstResponder(self.textView)
                if let container = self.textView.textContainer {
                    self.textView.layoutManager?.ensureLayout(forBoundingRect: self.scroll.contentView.bounds, in: container)
                }
                self.scroll.contentView.scroll(to: oldScroll)
                self.scroll.reflectScrolledClipView(self.scroll.contentView)
                self.selectingHeading = false
                self.scrolled()
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
                let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                self.status.stringValue = "只读  ·  \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))  ·  \(self.headings.count) 个标题  ·  \(Int(size)) pt"
                self.progress.stopAnimation(nil)
            } catch is CancellationError {
                // A newer file request owns the loading indicator.
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.progress.stopAnimation(nil)
                self.status.stringValue = "打开失败"
                let alert = NSAlert(error: error)
                if let window = self.window { await alert.beginSheetModal(for: window) }
            }
        }
    }

    func reload() { if let fileURL { open(fileURL) } }
    func reveal() { if let fileURL { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) } }
    func toggleSidebar() { sidebarItem.animator().isCollapsed.toggle() }
    func changeFontSize(by delta: CGFloat) {
        fontSize = min(28, max(12, fontSize + delta))
        UserDefaults.standard.set(fontSize, forKey: "fontSize")
        reload()
    }
    func resetFontSize() { changeFontSize(by: 16 - fontSize) }

    func numberOfRows(in tableView: NSTableView) -> Int { headings.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SolarizedRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("headingCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier
        if cell.textField == nil {
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        let heading = headings[row]
        let minimumLevel = headings.map(\.level).min() ?? 1
        let indentation = String(repeating: "  ", count: max(0, heading.level - minimumLevel))
        cell.textField?.stringValue = indentation + heading.title
        cell.textField?.font = .systemFont(ofSize: 12, weight: heading.level <= 2 ? .medium : .regular)
        cell.textField?.textColor = heading.level <= 2 ? Solarized.emphasized : Solarized.text
        cell.toolTip = heading.title
        return cell
    }

    @objc private func jumpToHeading() {
        guard headings.indices.contains(outline.selectedRow) else { return }
        jump(to: headings[outline.selectedRow])
    }

    private func jump(to heading: Heading) {
        selectingHeading = true
        textView.scrollRangeToVisible(heading.range)
        if let manager = textView.layoutManager, let container = textView.textContainer {
            let glyphs = manager.glyphRange(forCharacterRange: heading.range, actualCharacterRange: nil)
            let rect = manager.boundingRect(forGlyphRange: glyphs, in: container)
            let top = max(0, rect.minY + textView.textContainerInset.height - 24)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: top))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        textView.showFindIndicator(for: heading.range)
        selectingHeading = false
    }

    @objc private func scrolled() {
        guard !selectingHeading, !headings.isEmpty, let manager = textView.layoutManager, let container = textView.textContainer else { return }
        let point = NSPoint(x: 0, y: max(0, scroll.contentView.bounds.minY - textView.textContainerInset.height + 30))
        let glyph = manager.glyphIndex(for: point, in: container)
        guard glyph < manager.numberOfGlyphs else { return }
        let character = manager.characterIndexForGlyph(at: glyph)
        let row = headings.lastIndex(where: { $0.range.location <= character }) ?? 0
        if outline.selectedRow != row { outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL else { return false }
        if let fragment = url.fragment?.removingPercentEncoding,
           url.path == fileURL?.path,
           let row = headings.firstIndex(where: { $0.anchor == fragment }) {
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            jump(to: headings[row])
            return true
        }
        if url.isFileURL, ["md", "markdown", "mdown"].contains(url.pathExtension.lowercased()) {
            open(url)
            return true
        }
        return false
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.outline, .open, .flexibleSpace, .smaller, .larger, .find] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarAllowedItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        let config: (String, String, Selector)
        switch identifier {
        case .outline: config = ("文章目录", "sidebar.left", #selector(toggleFromToolbar))
        case .open: config = ("打开文件", "folder", #selector(openFromToolbar))
        case .smaller: config = ("缩小文字", "textformat.size.smaller", #selector(smallerFromToolbar))
        case .larger: config = ("放大文字", "textformat.size.larger", #selector(largerFromToolbar))
        case .find: config = ("查找 ⌘F", "magnifyingglass", #selector(findFromToolbar))
        default: return nil
        }
        item.label = config.0
        item.toolTip = config.0
        item.image = NSImage(systemSymbolName: config.1, accessibilityDescription: config.0)
        item.target = self
        item.action = config.2
        return item
    }

    @objc private func openFromToolbar() { chooseFile() }
    @objc private func toggleFromToolbar() { toggleSidebar() }
    @objc private func smallerFromToolbar() { changeFontSize(by: -1) }
    @objc private func largerFromToolbar() { changeFontSize(by: 1) }
    @objc private func findFromToolbar() {
        window?.makeFirstResponder(textView)
        let item = NSMenuItem(); item.tag = NSTextFinder.Action.showFindInterface.rawValue
        textView.performFindPanelAction(item)
    }
}

@MainActor
final class ReaderTextView: NSTextView {
    var openFile: ((URL) -> Void)?
    private var imageWidth: CGFloat = 0

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Repaint existing attributed text and table cells without reparsing the document.
        if let storage = textStorage {
            layoutManager?.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: storage.length))
        }
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        textContainerInset = NSSize(width: max(32, (newSize.width - 780) / 2), height: 36)
        resizeImages()
    }

    func resizeImages(force: Bool = false) {
        let width = max(100, min(700, bounds.width - textContainerInset.width * 2 - 12))
        guard force || width != imageWidth, let storage = textStorage else { return }
        imageWidth = width
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment, let image = attachment.image else { return }
            let scale = min(1, width / max(1, image.size.width))
            attachment.bounds.size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        droppedURL(sender) == nil ? [] : .copy
    }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let url = droppedURL(sender) else { return false }
        openFile?(url)
        return true
    }
    private func droppedURL(_ sender: any NSDraggingInfo) -> URL? {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first
    }
}
