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

// MARK: - WebViewState

/// 封装单个 WKWebView 的可观察状态，供 SwiftUI 绑定
final class WebViewState: ObservableObject {

    let webView: TopMarkWebView

    @Published var url: URL?
    @Published var title: String?
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0

    private var observations: [NSKeyValueObservation] = []

    init(webView: TopMarkWebView) {
        self.webView = webView
        syncState()
        setupObservations()
    }

    private func setupObservations() {
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.url = wv.url }
            },
            webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.title = wv.title }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.isLoading = wv.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoBack = wv.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoForward = wv.canGoForward }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.estimatedProgress = wv.estimatedProgress }
            }
        ]
    }

    func syncState() {
        url = webView.url
        title = webView.title
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        estimatedProgress = webView.estimatedProgress
    }
}

// MARK: - WebViewStore

final class WebViewStore: ObservableObject {

    // key 用 BookmarkItem.persistentModelID，确保每个书签独立
    private var storage: [PersistentIdentifier: WebViewState] = [:]
    @Published var closedIDs: Set<PersistentIdentifier> = []

    func webView(for item: BookmarkItem) -> TopMarkWebView {
        state(for: item).webView
    }

    func state(for item: BookmarkItem) -> WebViewState {
        let id = item.persistentModelID
        if let state = storage[id] {
            return state
        } else {
            let wv = WebCacheManager.shared.createWebView()
            if let url = URL(string: item.url) {
                wv.load(URLRequest(url: url))
            }
            let state = WebViewState(webView: wv)
            storage[id] = state
            closedIDs.remove(id)  // 访问即自动 reopen
            return state
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
        if let state = storage[id] {
            state.webView.stopLoading()
            state.webView.loadHTMLString("", baseURL: nil)  // 释放页面内容
        }
        storage[id] = nil
        closedIDs.insert(id)
    }

    func reopen(_ item: BookmarkItem) {
        closedIDs.remove(item.persistentModelID)
        _ = state(for: item)
    }

    func preload(items: [BookmarkItem]) {
        for item in items where item.preloadEnabled && !closedIDs.contains(item.persistentModelID) {
            _ = state(for: item)
        }
    }

    func remove(for itemID: PersistentIdentifier) {
        storage[itemID] = nil
        closedIDs.remove(itemID)
    }

    init() {

    }
}
