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
    @State private var newTitle = ""
    @State private var newURL = ""
    @State private var selectedItem: BookmarkItem?
    
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var statusBarController: StatusBarController
    // 内存层的 webview 缓存
    @StateObject private var webViewStore = WebViewStore()
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item, isSelected: item == selectedItem)
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
                        modelContext.delete(item)
                        selectedItem = nil
                    }
                }
            }
        })
        .onAppear {
            // 把“怎么开窗口”告诉 statusBarController
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
            NavigationStack {
                Form {
                    TextField("标题", text: $newTitle)
                    TextField("链接", text: $newURL)
                }
                .navigationTitle("添加书签")
                .padding(50)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            showingAddDialog = false
                            newTitle = ""
                            newURL = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") {
                            addItem()
                            showingAddDialog = false
                            newTitle = ""
                            newURL = ""
                        }
                        .disabled(newTitle.isEmpty || newURL.isEmpty)
                    }
                }
                .frame(minWidth: 300, minHeight: 150)
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = BookmarkItem(title: newTitle, url: newURL, order: items.count)
            modelContext.insert(newItem)
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

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct ItemRow: View {
    let item: BookmarkItem
    let isSelected: Bool
    var body: some View {
        HStack {
            Text(item.title)
            Spacer()
        }
    }
}

struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WebCacheManager.shared.createWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @objc func clearCache(_ sender: NSMenuItem) {
            WebCacheManager.shared.clearCache {
                print("Cache cleared successfully")
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 可以在这里添加页面加载完成后的处理
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BookmarkItem.self, inMemory: true)
}
