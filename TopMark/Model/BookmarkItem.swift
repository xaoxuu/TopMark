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
    
    init(title: String, url: String, order: Int) {
        self.title = title
        self.url = url
        self.order = order
    }
}
