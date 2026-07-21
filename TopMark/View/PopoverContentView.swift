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
                        if let selectedItem = selectedItem ?? items.first {
                            webViewStore.webView(for: selectedItem).load(URLRequest(url: URL(string: selectedItem.url)!))
                        }
                    } label: {
                        Image(systemName: "arrow.trianglehead.counterclockwise")
                            .frame(width: 16, height: 16)
                    }
                    Button {
                        if let selectedItem = selectedItem ?? items.first,
                           let url = URL(string: selectedItem.url) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "safari")
                            .frame(width: 16, height: 16)
                    }
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
                    .padding(.vertical, 128)
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
        TabButton(item: item, isSelected: selectedItem == item, action: { selectedItem = item })
            .opacity(draggingItem == item ? 0.3 : 1.0)
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
                Button("重命名", systemImage: "pencil") { renamingItem = item }
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
    
}

struct TabButton: View {
    let item: BookmarkItem
    let isSelected: Bool
    let action: () -> Void
    
    init(item: BookmarkItem, isSelected: Bool, action: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Text(item.title)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? Color.primary.opacity(1) : Color.primary.opacity(0.5))
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
