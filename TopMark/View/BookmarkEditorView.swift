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
    
    @State private var title: String = ""
    @State private var url: String = ""
    
    /// 输入完成后的回调
    let onSave: (BookmarkNewItem) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $title)
                TextField("链接", text: $url)
                    .autocorrectionDisabled()
            }
            .navigationTitle("添加书签")
            .padding(50)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if url.hasPrefix("http") {
                            onSave(.init(title: title, url: url))
                        } else {
                            onSave(.init(title: title, url: "https://" + url))
                        }
                        dismiss()
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
    }
}
