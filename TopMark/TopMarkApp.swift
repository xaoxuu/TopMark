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
    @StateObject private var webViewStore: WebViewStore = .shared
    
    init() {
        // 删除旧的数据库文件
//        clearOldDatabase()
    }
    
    var sharedModelContainer: ModelContainer = {
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
                    BookmarkItem(title: "欢迎", url: "https://xaoxuu.com/wiki/topmark/", order: 0),
                    BookmarkItem(title: "GitHub", url: "https://github.com/xaoxuu/topmark", order: 1),
                ]
                initialItems.forEach { context.insert($0) }
                try context.save()
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // 出问题时删除旧的数据库
    private func clearOldDatabase() {
        if let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dbPath = applicationSupportURL.appendingPathComponent("TopMark/bookmarks.store")
            try? FileManager.default.removeItem(at: dbPath)
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(statusBarController)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.setContentSize(windowManager.selectedSize.cgSize)
                    }
                    // 设置状态栏
                    statusBarController.setupPopover(with: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
}
