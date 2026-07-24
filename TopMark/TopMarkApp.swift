//
//  TopMarkApp.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/6.
//

import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

@main
struct TopMarkApp: App {
    
    @StateObject private var statusBarController = StatusBarController()
    @StateObject private var windowManager = WindowManager.shared
    @State private var mainWindowRef: NSWindow?
    @State private var windowResizeObserver: NSObjectProtocol?
    @State private var windowCloseObserver: NSObjectProtocol?
    
    init() {
    }
    
    var sharedModelContainer: ModelContainer = {
//        // 删除旧的数据库文件（迁移 windowType 字段后只需执行一次，之后可删除这行）
//        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
//            let dbPath = applicationSupportURL.appendingPathComponent("TopMark/bookmarks.store")
//            try? FileManager.default.removeItem(at: dbPath)
//        }
        
        do {
            // 配置数据存储路径
            let url = URL.applicationSupportDirectory.appending(path: "TopMark/bookmarks.store")
            // 确保目录存在
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
            
            // 创建 Schema
            let schema = Schema([BookmarkItem.self])
            let configuration = ModelConfiguration(
                schema: schema,
                url: url,
                allowsSave: true
            )
            
            // 创建容器
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // 按窗口类型独立判断并添加初始数据
            let context = container.mainContext
            let allItems = try context.fetch(FetchDescriptor<BookmarkItem>())
            
            // 为每个窗口类型独立设置默认书签
            let defaultItems: [(title: String, url: String, order: Int)] = [
                ("欢迎", "https://xaoxuu.com/wiki/topmark/", 0),
                ("GitHub", "https://github.com/xaoxuu/topmark", 1),
            ]
            
            var itemsToInsert: [BookmarkItem] = []
            for windowType in ["main", "popover"] {
                let windowItems = allItems.filter { $0.windowType == windowType }
                if windowItems.isEmpty {
                    for item in defaultItems {
                        itemsToInsert.append(BookmarkItem(
                            title: item.title, url: item.url, order: item.order,
                            windowType: windowType, preloadEnabled: true
                        ))
                    }
                }
            }
            
            if !itemsToInsert.isEmpty {
                itemsToInsert.forEach { context.insert($0) }
                try context.save()
            }
            
            if !allItems.isEmpty {
                // 迁移旧数据：确保所有现有数据都有 windowType
                var needsSave = false
                for item in allItems {
                    if item.windowType.isEmpty {
                        item.windowType = "main"
                        needsSave = true
                    }
                }
                if needsSave {
                    try context.save()
                }
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(statusBarController)
                .onAppear {
                    // 查找主窗口：排除 NSPanel（popover 内部窗口是 NSPanel 子类）
                    // 优先用缓存引用，但验证其有效性；否则重新查找
                    var window: NSWindow?
                    if let ref = mainWindowRef, ref.isVisible {
                        window = ref
                    } else {
                        mainWindowRef = nil
                        window = NSApplication.shared.windows.first(where: { ($0 as? NSPanel) == nil })
                    }
                    if let window {
                        mainWindowRef = window
                        window.setContentSize(windowManager.mainWindowSize.cgSize)
                        // 监听窗口尺寸变化并自动保存
                        if windowResizeObserver == nil {
                            windowResizeObserver = NotificationCenter.default.addObserver(
                                forName: NSWindow.didResizeNotification,
                                object: window,
                                queue: .main
                            ) { notification in
                                guard let win = notification.object as? NSWindow else { return }
                                let size = win.contentRect(forFrameRect: win.frame).size
                                let newSize = WindowSize(width: size.width, height: size.height)
                                if newSize != windowManager.mainWindowSize {
                                    windowManager.saveMainWindowSize(newSize)
                                }
                            }
                        }
                        // 监听窗口关闭时立即保存尺寸
                        if windowCloseObserver == nil {
                            windowCloseObserver = NotificationCenter.default.addObserver(
                                forName: NSWindow.willCloseNotification,
                                object: window,
                                queue: .main
                            ) { notification in
                                guard let win = notification.object as? NSWindow else { return }
                                let size = win.contentRect(forFrameRect: win.frame).size
                                windowManager.saveMainWindowSizeImmediately(WindowSize(width: size.width, height: size.height))
                            }
                        }
                    }
                    // 设置状态栏
                    statusBarController.setupPopover(with: sharedModelContainer)
                }
                .onDisappear {
                    if let observer = windowResizeObserver {
                        NotificationCenter.default.removeObserver(observer)
                        windowResizeObserver = nil
                    }
                    if let observer = windowCloseObserver {
                        NotificationCenter.default.removeObserver(observer)
                        windowCloseObserver = nil
                    }
                    mainWindowRef = nil
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // 「文件」菜单：导入/导出书签（直接操作数据库，与窗口可见性无关）
            CommandGroup(after: .importExport) {
                Button("导入书签（主窗口）…") {
                    importBookmarks(windowType: "main")
                }
                Button("导出书签（主窗口）…") {
                    exportBookmarks(windowType: "main")
                }
                Divider()
                Button("导入书签（Popover）…") {
                    importBookmarks(windowType: "popover")
                }
                Button("导出书签（Popover）…") {
                    exportBookmarks(windowType: "popover")
                }
            }
        }
    }
    
    /// 导出指定窗口类型的书签到下载文件夹，并在 Finder 中显示
    private func exportBookmarks(windowType: String) {
        do {
            let url = try BookmarkTransfer.exportBookmarks(windowType: windowType, from: sharedModelContainer.mainContext)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            showAlert(title: "导出失败", message: "无法写入下载文件夹。")
        }
    }
    
    /// 弹文件选择器，从 JSON 文件导入书签到指定窗口类型
    private func importBookmarks(windowType: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try BookmarkTransfer.importBookmarks(from: url, windowType: windowType, into: sharedModelContainer.mainContext)
        } catch {
            showAlert(title: "导入失败", message: "文件格式不正确，请选择有效的书签 JSON 文件。")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
}
