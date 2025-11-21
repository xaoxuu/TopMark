//
//  WebViewStore.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/7.
//

import SwiftUI
import Combine
import WebKit

final class WebViewStore: ObservableObject {
    
    static let shared = WebViewStore()
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
    func preload(items: [BookmarkItem]) {
        for item in items {
            _ = webView(for: item)
        }
    }
    func remove(for url: String) {
        storage[url] = nil
    }
    private init() {
        
    }
}

