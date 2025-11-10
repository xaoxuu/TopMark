import SwiftUI
import WebKit
import SwiftData

struct PopoverContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkItem.order) private var items: [BookmarkItem]
    @State private var selectedItem: BookmarkItem?
    
    @StateObject private var webViewStore = WebViewStore()
    
    init() {
        // 由于 init 中不能直接访问 items，所以在 onAppear 中设置默认选中项
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部 tab
            HStack(spacing: 0) {
                // 标签栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(items) { item in
                            TabButton(item: item, isSelected: selectedItem == item) {
                                selectedItem = item
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                
                // 在浏览器中打开
                HStack {
                    Button {
                        if let selectedItem = selectedItem ?? items.first {
                            webViewStore.webView(for: selectedItem).load(URLRequest(url: URL(string: selectedItem.url)!))
                        }
                    } label: {
                        Image(systemName: "arrow.trianglehead.counterclockwise")
                            .padding(2)
                    }
                    Button {
                        if let selectedItem = selectedItem ?? items.first,
                           let url = URL(string: selectedItem.url) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "safari")
                            .padding(2)
                    }
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .padding(8)

                
            }
            
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
                    Text("No bookmarks")
                        .padding(32)
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
        Button(action: action) {
            Text(item.title)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
        }
        .buttonStyle(.borderless)
        .background(isSelected ? Color.primary.opacity(0.1) : Color.clear)
        .foregroundColor(isSelected ? Color.primary.opacity(1) : Color.primary.opacity(0.5))
        .cornerRadius(32)
    }
}
