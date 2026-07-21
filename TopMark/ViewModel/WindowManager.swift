import Foundation
import AppKit
import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    /// Popover 窗口尺寸（跟随菜单设置）
    @Published var selectedSize: WindowSize
    /// 主窗口（独立窗口）尺寸（手动拖拽记忆）
    @Published var mainWindowSize: WindowSize
    
    let availableSizes: [WindowSize] = [
        WindowSize(title: "iPhone SE", width: 320, height: 568),
        WindowSize(title: "iPhone 13 mini", width: 375, height: 812),
        WindowSize(title: "Google Pixel 2 XL", width: 411, height: 823),
        WindowSize(title: "iPhone 17", width: 402, height: 874),
        WindowSize(title: "iPhone 17 Pro Max", width: 440, height: 956),
        WindowSize(title: "iPad mini 5 (Portrait)", width: 768, height: 1024),
        WindowSize(title: "iPad mini 5 (Landscape)", width: 1024, height: 768),
        WindowSize(title: "iPad mini 8.3 (Portrait)", width: 744, height: 1133),
        WindowSize(title: "iPad mini 8.3 (Landscape)", width: 1133, height: 744),
        WindowSize(title: "iPad Pro 11 (Landscape)", width: 1194, height: 834),
        WindowSize(title: "720P", width: 1280, height: 720),
    ]
    
    private var mainWindowSaveWorkItem: DispatchWorkItem?
    
    private init() {
        // 从 UserDefaults 读取 popover 尺寸
        if let savedWidth = UserDefaults.standard.object(forKey: "windowWidth") as? Double,
           let savedHeight = UserDefaults.standard.object(forKey: "windowHeight") as? Double {
            selectedSize = WindowSize(width: savedWidth, height: savedHeight)
        } else {
            selectedSize = WindowSize(width: 411, height: 823)
        }
        // 从 UserDefaults 读取主窗口尺寸
        if let savedWidth = UserDefaults.standard.object(forKey: "mainWindowWidth") as? Double,
           let savedHeight = UserDefaults.standard.object(forKey: "mainWindowHeight") as? Double {
            mainWindowSize = WindowSize(width: savedWidth, height: savedHeight)
        } else {
            mainWindowSize = WindowSize(width: 1280, height: 720)
        }
    }
    
    /// 保存 popover 窗口尺寸（菜单选择时调用）
    func saveWindowSize(_ size: WindowSize) {
        selectedSize = size
        UserDefaults.standard.set(size.width, forKey: "windowWidth")
        UserDefaults.standard.set(size.height, forKey: "windowHeight")
    }
    
    /// 保存主窗口尺寸（防抖，拖拽缩放时调用）
    func saveMainWindowSize(_ size: WindowSize) {
        mainWindowSize = size
        mainWindowSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            UserDefaults.standard.set(size.width, forKey: "mainWindowWidth")
            UserDefaults.standard.set(size.height, forKey: "mainWindowHeight")
        }
        mainWindowSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    /// 立即保存主窗口尺寸（无防抖），用于窗口关闭时
    func saveMainWindowSizeImmediately(_ size: WindowSize) {
        mainWindowSaveWorkItem?.cancel()
        mainWindowSize = size
        UserDefaults.standard.set(size.width, forKey: "mainWindowWidth")
        UserDefaults.standard.set(size.height, forKey: "mainWindowHeight")
    }
}

struct WindowSize: Identifiable, Equatable {
    let id = UUID()
    let width: Double
    let height: Double
    let title: String
    
    init(title: String? = nil, width: Double, height: Double) {
        self.width = width
        self.height = height
        self.title = title ?? "\(Int(width)) x \(Int(height))"
    }
    
    var sizeDescription: String {
        "\(Int(width))*\(Int(height))"
    }
    
    static func == (lhs: WindowSize, rhs: WindowSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
    
}
