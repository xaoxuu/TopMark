//
//  TopMarkWebView.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/21.
//

import AppKit
import WebKit

final class TopMarkWebView: WKWebView {

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        // 清空系统默认菜单项
        menu.removeAllItems()

        // 返回
        let backItem = NSMenuItem(title: "返回", action: #selector(goBackAction(_:)), keyEquivalent: "")
        backItem.image = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: nil)
        backItem.isEnabled = canGoBack
        backItem.target = self
        menu.addItem(backItem)

        // 前进
        let forwardItem = NSMenuItem(title: "前进", action: #selector(goForwardAction(_:)), keyEquivalent: "")
        forwardItem.image = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)
        forwardItem.isEnabled = canGoForward
        forwardItem.target = self
        menu.addItem(forwardItem)

        // 刷新
        let reloadItem = NSMenuItem(title: "刷新", action: #selector(reloadAction(_:)), keyEquivalent: "")
        reloadItem.image = NSImage(systemSymbolName: "arrow.trianglehead.counterclockwise", accessibilityDescription: nil)
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        // 复制当前链接
        let copyLinkItem = NSMenuItem(title: "复制当前链接", action: #selector(copyCurrentURL(_:)), keyEquivalent: "")
        copyLinkItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        copyLinkItem.target = self
        menu.addItem(copyLinkItem)

        // 在浏览器中打开
        let openInBrowserItem = NSMenuItem(title: "在浏览器中打开", action: #selector(openInBrowser(_:)), keyEquivalent: "")
        openInBrowserItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
        openInBrowserItem.target = self
        menu.addItem(openInBrowserItem)

        menu.addItem(.separator())

        // 检查元素
        let inspectItem = NSMenuItem(title: "检查元素", action: #selector(inspectElement(_:)), keyEquivalent: "")
        inspectItem.image = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: nil)
        inspectItem.target = self
        menu.addItem(inspectItem)
    }

    // MARK: - Actions

    @objc private func goBackAction(_ sender: Any?) {
        goBack()
    }

    @objc private func goForwardAction(_ sender: Any?) {
        goForward()
    }

    @objc private func reloadAction(_ sender: Any?) {
        reload()
    }

    @objc private func copyCurrentURL(_ sender: Any?) {
        if let url = url {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        }
    }

    @objc private func openInBrowser(_ sender: Any?) {
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func inspectElement(_ sender: Any?) {
        // isInspectable 已在 WebCacheManager 中设置为 true
        // 通过私有方法直接打开 Web Inspector 窗口
        if let inspector = perform(NSSelectorFromString("_inspector"))?.takeUnretainedValue() as? NSObject {
            inspector.perform(NSSelectorFromString("show"))
        }
    }
}
