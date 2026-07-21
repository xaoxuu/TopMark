//
//  WebViewStore.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/7.
//

import SwiftUI
import Combine
import WebKit
import SwiftData

final class WebViewStore: ObservableObject {
    
    // key 用 BookmarkItem.persistentModelID，确保每个书签独立
    private var storage: [PersistentIdentifier: WKWebView] = [:]
    @Published var closedIDs: Set<PersistentIdentifier> = []

    func webView(for item: BookmarkItem) -> WKWebView {
        let id = item.persistentModelID
        if let wv = storage[id] {
            return wv
        } else {
            let wv = WKWebView()
            if let url = URL(string: item.url) {
                wv.load(URLRequest(url: url))
            }
            storage[id] = wv
            closedIDs.remove(id)  // 访问即自动 reopen
            return wv
        }
    }
    
    func isClosed(_ item: BookmarkItem) -> Bool {
        closedIDs.contains(item.persistentModelID)
    }
    
    func isLoaded(_ item: BookmarkItem) -> Bool {
        storage[item.persistentModelID] != nil
    }
    
    func close(_ item: BookmarkItem) {
        let id = item.persistentModelID
        if let wv = storage[id] {
            wv.stopLoading()
            wv.loadHTMLString("", baseURL: nil)  // 释放页面内容
        }
        storage[id] = nil
        closedIDs.insert(id)
    }
    
    func reopen(_ item: BookmarkItem) {
        closedIDs.remove(item.persistentModelID)
        _ = webView(for: item)
    }
    
    func preload(items: [BookmarkItem]) {
        for item in items where item.preloadEnabled && !closedIDs.contains(item.persistentModelID) {
            _ = webView(for: item)
        }
    }
    
    func remove(for itemID: PersistentIdentifier) {
        storage[itemID] = nil
        closedIDs.remove(itemID)
    }
    
    init() {
        
    }
}
