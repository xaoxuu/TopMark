import WebKit
import Foundation

class WebCacheManager {
    
    static let shared = WebCacheManager()
    private let websiteDataStore = WKWebsiteDataStore.default()
    
    private init() {}
    
    // 创建一个配置为启用磁盘缓存的 WebView
    func createWebView() -> TopMarkWebView {
        let config = WKWebViewConfiguration()
        // 使用默认的持久化数据存储
        config.websiteDataStore = websiteDataStore
        // 配置缓存
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let webView = TopMarkWebView(frame: .zero, configuration: config)
        webView.allowsMagnification = true
        // macOS 13.3+ 启用 Web Inspector，支持检查元素
        webView.isInspectable = true
        return webView
    }
    
    // 清除所有缓存数据
    @objc func clearCache(completion: @escaping () -> Void) {
        print("start clean")
        let dataTypes = Set([WKWebsiteDataTypeDiskCache,
                           WKWebsiteDataTypeMemoryCache,
                           WKWebsiteDataTypeLocalStorage,
                           WKWebsiteDataTypeCookies,
                           WKWebsiteDataTypeSessionStorage,
                           WKWebsiteDataTypeIndexedDBDatabases,
                           WKWebsiteDataTypeWebSQLDatabases])
        
        let date = Date(timeIntervalSince1970: 0)
        websiteDataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
            DispatchQueue.main.async {
                completion()
                print("finish clean")
            }
        }
    }
}
