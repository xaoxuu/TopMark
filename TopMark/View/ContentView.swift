//
//  ContentView.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/6.
//

import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkItem.order) private var items: [BookmarkItem]
    @State private var showingAddDialog = false
    @State private var selectedItem: BookmarkItem?
    
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var statusBarController: StatusBarController
    // 主窗口独立的 webview 缓存
    @StateObject private var webViewStore = WebViewStore()
    
    init() {
        let windowType = "main"
        _items = Query(filter: #Predicate<BookmarkItem> { $0.windowType == windowType }, sort: \BookmarkItem.order)
    }
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        Text(item.title)
                    }
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
                let webView = webViewStore.webView(for: item)
                WebViewContainer(webView: webView)
                    .navigationTitle(item.title)
                    .id(item.url)
            } else if let item = items.first {
                let webView = webViewStore.webView(for: item)
                WebViewContainer(webView: webView)
                    .navigationTitle(item.title)
                    .id(item.url)
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
        .toolbar(content: {
            Button("刷新", systemImage: "arrow.trianglehead.counterclockwise") {
                if let item = selectedItem ?? items.first {
                    webViewStore.webView(for: item).load(URLRequest(url: URL(string: item.url)!))
                }
            }
            Button("浏览器打开", systemImage: "safari") {
                if let item = selectedItem ?? items.first,
                   let url = URL(string: item.url) {
                    NSWorkspace.shared.open(url)
                }
            }
            Menu("操作", systemImage: "ellipsis.circle") {
                Button("删除", systemImage: "trash") {
                    if let item = selectedItem ?? items.first {
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
                        modelContext.delete(item)
                        selectedItem = next
                        if next == nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    selectedItem = nil
                                }
                            }
                        }
                    }
                }
            }
        })
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
    }

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
        }
    }
    
}

#Preview {
    ContentView()
        .modelContainer(for: BookmarkItem.self, inMemory: true)
}
