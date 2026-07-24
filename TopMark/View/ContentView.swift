//
//  ContentView.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/6.
//

import SwiftUI
import SwiftData
import WebKit
import UniformTypeIdentifiers

struct ContentView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkItem.order) private var items: [BookmarkItem]
    @State private var showingAddDialog = false
    @State private var selectedItem: BookmarkItem?
    @State private var renamingItem: BookmarkItem?
    @State private var showingImporter = false
    @State private var exportedURL: URL?
    @State private var exportFailed = false
    @State private var importFailed = false
    
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var statusBarController: StatusBarController
    // 主窗口独立的 webview 缓存
    @StateObject private var webViewStore = WebViewStore()
    
    init() {
        let windowType = "main"
        _items = Query(filter: #Predicate<BookmarkItem> { $0.windowType == windowType }, sort: \BookmarkItem.order)
    }

    /// 当前活跃书签（优先选中项，否则取第一项）
    private var activeItem: BookmarkItem? {
        selectedItem ?? items.first
    }

    /// 当前活跃的 WebViewState
    private var activeWebViewState: WebViewState? {
        activeItem.map { webViewStore.state(for: $0) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        Text(item.title)
                    }
                    .contextMenu {
                        contextMenuItems(for: item)
                    }
                    .foregroundStyle(webViewStore.isLoaded(item) ? Color.primary.opacity(1) : Color.primary.opacity(0.3))
                }
                .onMove(perform: moveItems)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                ToolbarItem {
                    Button(action: { showingAddDialog = true }) {
                        Label("添加书签", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let item = selectedItem {
                let webViewState = webViewStore.state(for: item)
                WebViewContainer(webView: webViewState.webView)
                    .navigationTitle(item.title)
                    .id(item.persistentModelID)
            } else if let item = items.first {
                let webViewState = webViewStore.state(for: item)
                WebViewContainer(webView: webViewState.webView)
                    .navigationTitle(item.title)
                    .id(item.persistentModelID)
                    .onAppear {
                        selectedItem = item
                    }
            } else {
                Button(action: { showingAddDialog = true }) {
                    Label("添加书签", systemImage: "plus")
                        .padding(16)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .frame(minWidth: 360, idealWidth: 1280, maxWidth: .infinity, minHeight: 500, idealHeight: 720, maxHeight: .infinity)
        .toolbar {
//            // 重置到书签原始地址
//            ToolbarItem(placement: .navigation) {
//                
//            }
            ToolbarItemGroup(placement: .primaryAction) {
                // 重置到书签原始地址
                Button(action: {
                    if let item = activeItem, let url = URL(string: item.url) {
                        activeWebViewState?.webView.load(URLRequest(url: url))
                    }
                }) {
                    Image(systemName: "arrow.trianglehead.counterclockwise")
                }
                .disabled(activeItem == nil)
                .help("重载书签")
                // 在浏览器中打开
                Button(action: {
                    if let url = activeWebViewState?.url {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "safari")
                }
                .disabled(activeWebViewState?.url == nil)
                .help("在浏览器中打开")
            }
            ToolbarItem {
                Menu {
                    Button(action: { showingImporter = true }) {
                        Label("导入书签", systemImage: "square.and.arrow.down")
                    }
                    Button(action: exportBookmarks) {
                        Label("导出书签", systemImage: "square.and.arrow.up")
                    }
                    .disabled(items.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .help("导入/导出书签")
            }
        }
        .onAppear {
            statusBarController.bindOpenMainWindow {
                openWindow(id: "main")
            }
            if selectedItem == nil {
                selectedItem = items.first
            }
            // 这里一进来就把所有页面预热
            webViewStore.preload(items: items)
        }
        .onChange(of: items, { oldValue, newValue in
            webViewStore.preload(items: newValue)
        })
        .sheet(isPresented: $showingAddDialog) {
            BookmarkEditorView { newItem in
                addItem(newItem: newItem)
            }
        }
        .sheet(item: $renamingItem) { item in
            BookmarkEditorView(item: item) { _ in }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                importBookmarks(from: url)
            }
        }
        .modifier(BookmarkTransferAlerts(exportedURL: $exportedURL, exportFailed: $exportFailed, importFailed: $importFailed))
    }

    // MARK: - 子视图

    @ViewBuilder
    private func contextMenuItems(for item: BookmarkItem) -> some View {
        Button("重载书签", systemImage: "arrow.trianglehead.counterclockwise") {
            webViewStore.webView(for: item).load(URLRequest(url: URL(string: item.url)!))
        }
        Button("在浏览器中打开", systemImage: "safari") {
            if let url = URL(string: item.url) { NSWorkspace.shared.open(url) }
        }
        Button("关闭标签页", systemImage: "xmark") { closeTab(item) }
        Divider()
        Button("编辑书签", systemImage: "pencil") {
            renamingItem = item
        }
        Button("删除书签", systemImage: "trash", role: .destructive) {
            deleteItem(item)
        }
    }

    // MARK: - 数据操作

    private func moveItems(from source: IndexSet, to destination: Int) {
        var updatedItems = items
        updatedItems.move(fromOffsets: source, toOffset: destination)
        
        // Update order for all items
        for (index, item) in updatedItems.enumerated() {
            item.order = index
        }
    }
    
    private func addItem(newItem: BookmarkNewItem) {
        withAnimation {
            let item = BookmarkItem(item: newItem, order: items.count, windowType: "main")
            modelContext.insert(item)
            let popoverItem = BookmarkItem(item: newItem, order: items.count, windowType: "popover")
            modelContext.insert(popoverItem)
        }
    }
    
    /// 导出书签到下载文件夹
    private func exportBookmarks() {
        do {
            exportedURL = try BookmarkTransfer.saveToDownloads(items: items)
        } catch {
            exportFailed = true
        }
    }
    
    /// 从 JSON 文件导入书签：合并追加
    private func importBookmarks(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let parsed = try? BookmarkTransfer.parse(data: data) else {
            importFailed = true
            return
        }
        var order = (items.map(\.order).max() ?? -1) + 1
        withAnimation {
            for transferItem in parsed {
                let item = BookmarkItem(title: transferItem.title, url: transferItem.url, order: order, windowType: "main", preloadEnabled: transferItem.preloadEnabled)
                modelContext.insert(item)
                order += 1
            }
        }
    }
    
    private func deleteItem(_ item: BookmarkItem) {
        let idx = items.firstIndex(of: item)
        var next: BookmarkItem?
        if let idx, items.count > 1 {
            if idx + 1 < items.count {
                next = items[idx+1]
            } else if idx < items.count {
                next = items[idx]
            }
            if next == item, idx - 1 >= 0 {
                next = items[idx-1]
            }
        }
        withAnimation {
            modelContext.delete(item)
        }
        selectedItem = next
        if next == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    selectedItem = nil
                }
            }
        }
    }
    
    private func closeTab(_ item: BookmarkItem) {
        webViewStore.close(item)
        // 如果关闭的是当前选中的，切换到下一个打开的标签
        if selectedItem == item {
            let openItems = items.filter { !webViewStore.isClosed($0) }
            if let currentIdx = items.firstIndex(of: item) {
                selectedItem = openItems.first(where: { (items.firstIndex(of: $0) ?? -1) > currentIdx })
                    ?? openItems.last
            }
        }
    }
    
}

#Preview {
    ContentView()
        .modelContainer(for: BookmarkItem.self, inMemory: true)
}
