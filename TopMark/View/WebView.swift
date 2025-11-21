//
//  WebView.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/10.
//

import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeCoordinator() -> Coordinator {
        Coordinator(webView: webView)
    }

    func makeNSView(context: Context) -> WKWebView {
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        
    }

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKDownloadDelegate {
        private weak var webView: WKWebView?

        init(webView: WKWebView) {
            self.webView = webView
        }

        // 处理 target=_blank / window.open
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            // 没有目标frame，说明想开新窗口
            if navigationAction.targetFrame == nil,
               let mainWebView = self.webView {
                mainWebView.load(navigationAction.request)
            }
            // 返回 nil 表示我们自己处理了
            return nil
        }
        
        // 1) 有些下载是从点击链接触发的
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            // macOS 12+ 有这个属性，表示这是要下载的
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }

            decisionHandler(.allow)
        }

        // 2) 有些下载是从响应头触发的（比如 Content-Disposition: attachment）
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                // 不能显示，就走下载
                decisionHandler(.download)
            }
        }

        // 3) 真正变成下载对象时会走这里
        func webView(_ webView: WKWebView,
                     navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView,
                     navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        // 4) 指定下载保存位置
        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            let downloads = FileManager.default.urls(for: .downloadsDirectory,
                                                            in: .userDomainMask).first!
            var dest = downloads.appendingPathComponent(suggestedFilename)
            if FileManager.default.fileExists(atPath: dest.path) {
                let baseName = dest.deletingPathExtension().lastPathComponent
                let ext = dest.pathExtension
                let timestamp = Int(Date().timeIntervalSince1970)
                let newName = "\(baseName)-\(timestamp).\(ext)"
                dest = downloads.appendingPathComponent(newName)
            }
            completionHandler(dest)
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            print("download failed:", error)
        }

        func downloadDidFinish(_ download: WKDownload) {
            print("download finished")
        }
        
    }
}
