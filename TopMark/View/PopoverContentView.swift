import SwiftUI
import WebKit
import SwiftData
import UniformTypeIdentifiers

struct PopoverContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkItem.order) private var items: [BookmarkItem]
    @State private var selectedItem: BookmarkItem?
    @State private var showingAddDialog = false
    @State private var renamingItem: BookmarkItem?
    @StateObject private var webViewStore = WebViewStore()
    @State private var draggingItem: BookmarkItem?
    @ObservedObject private var windowManager = WindowManager.shared
    
    init() {
        let windowType = "popover"
        _items = Query(filter: #Predicate<BookmarkItem> { $0.windowType == windowType }, sort: \BookmarkItem.order)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部 tab
            HStack(spacing: 0) {
                // 标签栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(items) { item in
                            makeTabItem(item)
                        }
                    }
                    .padding(8)
                }
                
                HStack {
                    Button {
                        showingAddDialog = true
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 16, height: 16)
                    }
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .padding(.trailing, 8)
            }
            .frame(height: 40)
            
            Divider()
            
            // 网页内容
            Group {
                if let item = selectedItem {
                    let webView = webViewStore.webView(for: item)
                    WebViewContainer(webView: webView)
                        .navigationTitle(item.title)
                        .id(item.persistentModelID)
                } else if let item = items.first {
                    let webView = webViewStore.webView(for: item)
                    WebViewContainer(webView: webView)
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
                    .padding(.vertical, 800)
                }
            }
            .onAppear {
                if selectedItem == nil, let firstItem = items.first {
                    selectedItem = firstItem
                }
                // 这里一进来就把所有页面预热
                webViewStore.preload(items: items)
            }
            .onChange(of: items, { oldValue, newValue in
                webViewStore.preload(items: newValue)
            })
        }
        .frame(width: windowManager.selectedSize.width, height: windowManager.selectedSize.height)
        .sheet(isPresented: $showingAddDialog) {
            BookmarkEditorView { newItem in
                addItem(newItem: newItem)
            }
        }
        .sheet(item: $renamingItem) { item in
            BookmarkEditorView(item: item) { _ in }
        }
    }
    
    
    private func moveItems(from sourceIndex: Int, to destIndex: Int) {
        var updatedItems = items
        let movedItem = updatedItems.remove(at: sourceIndex)
        updatedItems.insert(movedItem, at: destIndex)
        for (index, item) in updatedItems.enumerated() {
            item.order = index
        }
    }
    
    @ViewBuilder
    private func makeTabItem(_ item: BookmarkItem) -> some View {
        TabButton(item: item, isSelected: selectedItem == item,
                  isLoaded: webViewStore.isLoaded(item),
                  isClosed: webViewStore.isClosed(item),
                  action: { selectedItem = item })
            .opacity(draggingItem == item ? 0.2 : 1.0)
            .onDrag {
                draggingItem = item
                return NSItemProvider(object: String(items.firstIndex(of: item) ?? 0) as NSString)
            }
            .onDrop(
                of: [.text],
                delegate: TabReorderDelegate(
                    targetItem: item,
                    items: items,
                    moveItems: moveItems,
                    draggingItem: $draggingItem
                )
            )
            .contextMenu {
                Button("刷新", systemImage: "arrow.trianglehead.counterclockwise") {
                    webViewStore.webView(for: item).load(URLRequest(url: URL(string: item.url)!))
                }
                Button("浏览器打开", systemImage: "safari") {
                    if let url = URL(string: item.url) { NSWorkspace.shared.open(url) }
                }
                Button("关闭标签页", systemImage: "xmark") { closeTab(item) }
                Divider()
                Button("编辑", systemImage: "pencil") { renamingItem = item }
                Button("删除", systemImage: "trash", role: .destructive) { deleteItem(item) }
            }
    }
    
    private func addItem(newItem: BookmarkNewItem) {
        withAnimation {
            let item = BookmarkItem(item: newItem, order: items.count, windowType: "popover")
            modelContext.insert(item)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                // 优先选后面的，再选前面的
                selectedItem = openItems.first(where: { (items.firstIndex(of: $0) ?? -1) > currentIdx })
                    ?? openItems.last
            }
        }
    }
    
}

struct TabButton: View {
    let item: BookmarkItem
    let isSelected: Bool
    let isLoaded: Bool
    let isClosed: Bool
    let action: () -> Void
    
    init(item: BookmarkItem, isSelected: Bool, isLoaded: Bool = true, isClosed: Bool = false, action: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.isLoaded = isLoaded
        self.isClosed = isClosed
        self.action = action
    }
    
    var body: some View {
        Text(item.title)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white.opacity(1) : Color.clear)
            .foregroundColor(
                isSelected ? Color.primary :
                isLoaded ? Color.primary :
                Color.primary.opacity(0.3)
            )
            .cornerRadius(32)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

struct TabReorderDelegate: DropDelegate {
    let targetItem: BookmarkItem
    let items: [BookmarkItem]
    let moveItems: (Int, Int) -> Void
    @Binding var draggingItem: BookmarkItem?
    
    func dropEntered(info: DropInfo) {
        guard let dragItem = draggingItem,
              dragItem != targetItem,
              let fromIndex = items.firstIndex(of: dragItem),
              let toIndex = items.firstIndex(of: targetItem) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            moveItems(fromIndex, toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> NSDragOperation? {
        return .move
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}
