import SwiftUI
import AppKit
import Combine
import SwiftData
import ServiceManagement

@MainActor
final class StatusBarController: ObservableObject {
    
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var modelContainer: ModelContainer?
    @Published private(set) var isPopoverShown = false
    
    private var openWindowHandler: (() -> Void)?
    
    // 给外面调用，用来注册
    func bindOpenMainWindow(_ handler: @escaping () -> Void) {
        self.openWindowHandler = handler
    }
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        
        if let button = statusItem.button {
            button.image = NSImage(named: "bookmark")
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    func setupPopover(with modelContainer: ModelContainer) {
        // 已经配置过就不重复设置，避免重新创建 contentViewController 导致 popover 尺寸重置
        guard popover.contentViewController == nil else { return }
        self.modelContainer = modelContainer
        popover.contentSize = WindowManager.shared.selectedSize.cgSize
        let contentView = PopoverContentView()
        popover.contentViewController = NSHostingController(rootView: contentView.modelContainer(modelContainer))
        popover.behavior = .applicationDefined
    }
    
    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                showSizeMenu(sender)
            } else {
                if popover.isShown {
                    closePopover()
                } else {
                    showPopover(sender)
                }
            }
        }
    }
    
    private func showSizeMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        // 添加右键菜单
        menu.addItem(NSMenuItem.separator())
        let openItem = NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 窗口尺寸
        let sizeTitle = NSMenuItem()
        sizeTitle.title = "窗口尺寸"
        sizeTitle.isEnabled = false
        menu.addItem(sizeTitle)
        
        // 添加尺寸选项
        for size in WindowManager.shared.availableSizes {
            let item = NSMenuItem(title: "", action: #selector(changeWindowSize(_:)), keyEquivalent: "")
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 280, options: [:])]
            paragraphStyle.headIndent = 0
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paragraphStyle
            ]
            let dimAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .paragraphStyle: paragraphStyle
            ]
            
            let attributed = NSMutableAttributedString()
            attributed.append(NSAttributedString(string: size.title, attributes: titleAttrs))
            attributed.append(NSAttributedString(string: "  (\(size.sizeDescription))", attributes: dimAttrs))
            item.attributedTitle = attributed
            
            item.target = self
            item.representedObject = size
            item.state = size == WindowManager.shared.selectedSize ? .on : .off
            menu.addItem(item)
        }
        
        // 添加右键菜单
        menu.addItem(NSMenuItem.separator())
        let cleanItem = NSMenuItem(title: "清除网页缓存", action: #selector(clearCache(_:)), keyEquivalent: "")
        cleanItem.target = self
        menu.addItem(cleanItem)
        
        
        // 开机自启开关
        let launchItem = NSMenuItem(title: "开机自启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let openURL1 = NSMenuItem(title: base64Decoding(encodedString: "6aG555uu5rqQ56CB") ?? "??", action: #selector(openURL(_:)), keyEquivalent: "")
        openURL1.target = self
        menu.addItem(openURL1)
        
        menu.addItem(NSMenuItem.separator())
        
        // 添加分隔线和退出选项
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出程序", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // 清除菜单，这样下次左键点击还能正常工作
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let willEnable = sender.state == .off
        do {
            if willEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            sender.state = willEnable ? .on : .off
        } catch {
            // 失败就恢复原状态
            sender.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            print("设置开机自启失败:", error)
        }
    }
    @objc func clearCache(_ sender: NSMenuItem) {
        WebCacheManager.shared.clearCache {
            
        }
    }
    @objc func openMainWindow(_ sender: NSMenuItem) {
        openWindowHandler?()
        NSApplication.shared.activate()
        // 延迟确保主窗口已完全创建和布局完成，然后设置尺寸
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.applyMainWindowSize()
        }
    }
    
    /// 查找主窗口（排除 NSPanel）并应用保存的尺寸
    func applyMainWindowSize() {
        guard let window = NSApplication.shared.windows.first(where: { ($0 as? NSPanel) == nil }) else { return }
        window.setContentSize(WindowManager.shared.mainWindowSize.cgSize)
    }
    @objc private func changeWindowSize(_ sender: NSMenuItem) {
        if let size = sender.representedObject as? WindowSize {
            WindowManager.shared.saveWindowSize(size)
            // 只更新尺寸，不重新创建视图
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                popover.contentSize = size.cgSize
            }
        }
    }
    @objc private func openURL(_ sender: NSMenuItem) {
        if let str = base64Decoding(encodedString: "aHR0cHM6Ly9naXRodWIuY29tL3hhb3h1dS90b3BtYXJr"), let url = URL(string: str) {
            NSWorkspace.shared.open(url)
        }
    }
    private func base64Decoding(encodedString: String) -> String? {
        guard let decodedData = Data(base64Encoded: encodedString, options: Data.Base64DecodingOptions(rawValue: 0)) else {
            return nil
        }
        return String(data: decodedData, encoding: .utf8)
    }
    private func showPopover(_ sender: NSStatusBarButton) {
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        isPopoverShown = true
    }
    
    private func closePopover() {
        popover.performClose(nil)
        isPopoverShown = false
    }
}

extension WindowSize {
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}
