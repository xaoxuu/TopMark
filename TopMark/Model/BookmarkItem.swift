//
//  Item.swift
//  TopMark
//
//  Created by xaoxuu on 2025/11/6.
//

import Foundation
import SwiftData

@Model
final class BookmarkItem {
    
    var title: String
    var url: String
    var order: Int
    /// 所属窗口类型: "main" 或 "popover"
    var windowType: String
    /// 启动时是否预加载
    var preloadEnabled: Bool
    
    init(title: String, url: String, order: Int, windowType: String = "main", preloadEnabled: Bool = false) {
        self.title = title
        self.url = url
        self.order = order
        self.windowType = windowType
        self.preloadEnabled = preloadEnabled
    }
    
    init(item: BookmarkNewItem, order: Int, windowType: String = "main") {
        self.title = item.title
        self.url = item.url
        self.order = order
        self.windowType = windowType
        self.preloadEnabled = item.preloadEnabled
    }
    
}

struct BookmarkNewItem {
    var title: String
    var url: String
    var preloadEnabled: Bool
}
