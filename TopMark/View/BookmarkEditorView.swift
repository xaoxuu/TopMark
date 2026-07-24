//
//  BookmarkEditorView.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/10.
//

import SwiftUI
import AppKit

struct BookmarkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var url: String
    @State private var preloadEnabled: Bool
    
    /// 编辑模式下的原始 item（为 nil 表示新增模式）
    private let editingItem: BookmarkItem?
    /// 输入完成后的回调（新增模式）
    private let onSave: ((BookmarkNewItem) -> Void)?
    /// 编辑完成后的回调（编辑模式）
    private let onUpdate: ((BookmarkItem) -> Void)?
    
    /// 新增模式
    init(onSave: @escaping (BookmarkNewItem) -> Void) {
        self.editingItem = nil
        self.onSave = onSave
        self.onUpdate = nil
        _title = State(initialValue: "")
        _url = State(initialValue: "")
        _preloadEnabled = State(initialValue: true)
    }
    
    /// 编辑模式
    init(item: BookmarkItem, onUpdate: @escaping (BookmarkItem) -> Void) {
        self.editingItem = item
        self.onSave = nil
        self.onUpdate = onUpdate
        _title = State(initialValue: item.title)
        _url = State(initialValue: item.url)
        _preloadEnabled = State(initialValue: item.preloadEnabled)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $title)
                TextField("链接", text: $url)
                    .autocorrectionDisabled()
                Toggle("启动后预加载", isOn: $preloadEnabled)
            }
            .navigationTitle(editingItem == nil ? "添加书签" : "编辑书签")
            .padding(50)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        let finalURL = url.hasPrefix("http") ? url : "https://" + url
                        if let editingItem = editingItem {
                            editingItem.title = title
                            editingItem.url = finalURL
                            editingItem.preloadEnabled = preloadEnabled
                            onUpdate?(editingItem)
                        } else {
                            onSave?(.init(title: title, url: finalURL, preloadEnabled: preloadEnabled))
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
    }
}
