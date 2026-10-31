import AppKit

@main
enum MDVApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var reader: ReaderWindowController?
    private var pendingURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        let controller = ReaderWindowController()
        reader = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let url = pendingURL { controller.open(url) }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if let reader { reader.showWindow(nil); reader.open(url) } else { pendingURL = url }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reader?.showWindow(nil)
        return true
    }

    @objc func openDocument(_ sender: Any?) { reader?.chooseFile() }
    @objc func reload(_ sender: Any?) { reader?.reload() }
    @objc func toggleSidebar(_ sender: Any?) { reader?.toggleSidebar() }
    @objc func zoomIn(_ sender: Any?) { reader?.changeFontSize(by: 1) }
    @objc func zoomOut(_ sender: Any?) { reader?.changeFontSize(by: -1) }
    @objc func resetZoom(_ sender: Any?) { reader?.resetFontSize() }
    @objc func reveal(_ sender: Any?) { reader?.reveal() }

    private func buildMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 MDV", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 MDV", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 MDV", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)

        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "打开…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "重新载入", action: #selector(reload(_:)), keyEquivalent: "r")
        fileMenu.addItem(withTitle: "在 Finder 中显示", action: #selector(reveal(_:)), keyEquivalent: "")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileItem = NSMenuItem(); fileItem.submenu = fileMenu; menu.addItem(fileItem)

        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let find = editMenu.addItem(withTitle: "查找…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        let next = editMenu.addItem(withTitle: "查找下一个", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
        next.tag = NSTextFinder.Action.nextMatch.rawValue
        let editItem = NSMenuItem(); editItem.submenu = editMenu; menu.addItem(editItem)

        let viewMenu = NSMenu(title: "显示")
        let sidebar = viewMenu.addItem(withTitle: "显示 / 隐藏目录", action: #selector(toggleSidebar(_:)), keyEquivalent: "s")
        sidebar.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "放大文字", action: #selector(zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "缩小文字", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "实际大小", action: #selector(resetZoom(_:)), keyEquivalent: "0")
        let viewItem = NSMenuItem(); viewItem.submenu = viewMenu; menu.addItem(viewItem)

        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        let windowItem = NSMenuItem(); windowItem.submenu = windowMenu; menu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
    }
}
