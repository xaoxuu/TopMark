//
//  WebViewStore.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/7.
//

import SwiftUI
import Combine
import WebKit

// 1. 做一个在内存里缓存 webview 的管理器
final class WebViewStore: ObservableObject {
    // key 用 BookmarkItem.id
    private var storage: [String: WKWebView] = [:]

    func webView(for item: BookmarkItem) -> WKWebView {
        if let wv = storage[item.url] {
            return wv
        } else {
            let wv = WKWebView()
            if let url = URL(string: item.url) {
                wv.load(URLRequest(url: url))
            }
            storage[item.url] = wv
            return wv
        }
    }
    // 新增：一次性预加载
    func preload(items: [BookmarkItem]) {
        for item in items {
            _ = webView(for: item)  // 调用一下就会建+load
        }
    }
    // 如果你会删书签，可以给个删除方法
    func remove(for url: String) {
        storage[url] = nil
    }
}

// 2. SwiftUI 包装
struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {
        
    }
}
