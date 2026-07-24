//
//  BookmarkTransfer.swift
//  TopMark
//
//  Created by xaoxuu on 2026/7/24.
//

import Foundation
import SwiftUI

/// 用于 JSON 导入/导出的书签传输模型
struct BookmarkTransferItem: Codable {
    var title: String
    var url: String
    var preloadEnabled: Bool
}

/// 书签导入/导出辅助
enum BookmarkTransfer {

    /// 将书签列表编码为 JSON 数据（按 order 排序）
    static func exportData(items: [BookmarkItem]) -> Data {
        let transferItems = items
            .sorted { $0.order < $1.order }
            .map { BookmarkTransferItem(title: $0.title, url: $0.url, preloadEnabled: $0.preloadEnabled) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(transferItems)) ?? Data()
    }

    /// 从 JSON 数据解析书签列表，过滤掉 title/url 为空的无效条目
    static func parse(data: Data) throws -> [BookmarkTransferItem] {
        let decoded = try JSONDecoder().decode([BookmarkTransferItem].self, from: data)
        return decoded.filter { !$0.title.isEmpty && !$0.url.isEmpty }
    }

    /// 将书签导出到下载文件夹，返回保存的文件 URL（重名时自动追加时间戳）
    static func saveToDownloads(items: [BookmarkItem]) throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var dest = downloads.appendingPathComponent("TopMark书签.json")
        if FileManager.default.fileExists(atPath: dest.path) {
            let timestamp = Int(Date().timeIntervalSince1970)
            dest = downloads.appendingPathComponent("TopMark书签-\(timestamp).json")
        }
        try exportData(items: items).write(to: dest, options: .atomic)
        return dest
    }

}

/// 导入/导出结果弹窗修饰符（主窗口与 Popover 共用）
struct BookmarkTransferAlerts: ViewModifier {

    @Binding var exportedURL: URL?
    @Binding var exportFailed: Bool
    @Binding var importFailed: Bool

    func body(content: Content) -> some View {
        content
            .alert("导出成功", isPresented: Binding(get: { exportedURL != nil }, set: { if !$0 { exportedURL = nil } })) {
                Button("在 Finder 中显示") {
                    if let exportedURL { NSWorkspace.shared.activateFileViewerSelecting([exportedURL]) }
                }
                Button("好", role: .cancel) {}
            } message: {
                Text("书签已导出到下载文件夹。")
            }
            .alert("导出失败", isPresented: $exportFailed) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("无法写入下载文件夹。")
            }
            .alert("导入失败", isPresented: $importFailed) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("文件格式不正确，请选择有效的书签 JSON 文件。")
            }
    }

}
