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
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item, modelContext: modelContext, selectedItem: $selectedItem)
                    }
                }
                .onMove(perform: moveItems)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                ToolbarItem {
                    Button(action: { showingAddDialog = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let selectedItem = selectedItem {
                WebViewContainer(url: URL(string: selectedItem.url))
                    .navigationTitle(selectedItem.title)
            } else {
                Text("Select a bookmark")
            }
        }
        .sheet(isPresented: $showingAddDialog) {
            NavigationStack {
                Form {
                    TextField("Title", text: $newTitle)
                    TextField("URL", text: $newURL)
                }
                .navigationTitle("Add Bookmark")
                .padding(50)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddDialog = false
                            newTitle = ""
                            newURL = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
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
    let modelContext: ModelContext
    @Binding var selectedItem: BookmarkItem?
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Text(item.title)
            Spacer()
            if isHovered {
                Button(action: {
                    modelContext.delete(item)
                    selectedItem = nil
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WebViewContainer: View {
    let url: URL?
    
    var body: some View {
        if let url = url {
            WebView(url: url)
        } else {
            Text("Invalid URL")
        }
    }
}

struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BookmarkItem.self, inMemory: true)
}
