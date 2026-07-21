//
//  TopMarkApp.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/6.
//

import SwiftUI
import SwiftData
import Combine

@main
struct TopMarkApp: App {
    
    @StateObject private var statusBarController = StatusBarController()
    @StateObject private var windowManager = WindowManager.shared
    @State private var windowResizeObserver: NSObjectProtocol?
    @State private var windowCloseObserver: NSObjectProtocol?
    
    init() {
    }
    
    var sharedModelContainer: ModelContainer = {
        // 删除旧的数据库文件（迁移 windowType 字段后只需执行一次，之后可删除这行）
        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dbPath = applicationSupportURL.appendingPathComponent("TopMark/bookmarks.store")
            try? FileManager.default.removeItem(at: dbPath)
        }
        
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
            
            // 添加初始数据（只在数据库为空时添加）
            let context = container.mainContext
            let existingItems = try context.fetch(FetchDescriptor<BookmarkItem>())
            if existingItems.isEmpty {
                let initialItems = [
                    BookmarkItem(title: "欢迎", url: "https://xaoxuu.com/wiki/topmark/", order: 0, windowType: "main"),
                    BookmarkItem(title: "GitHub", url: "https://github.com/xaoxuu/topmark", order: 1, windowType: "main"),
                ]
                initialItems.forEach { context.insert($0) }
                try context.save()
            } else {
                // 迁移旧数据：确保所有现有数据都有 windowType
                var needsSave = false
                for item in existingItems {
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
                    if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.className.contains("NSWindow") }) ?? NSApplication.shared.windows.first {
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
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
}
