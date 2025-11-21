import Foundation
import AppKit
import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    @Published var selectedSize: WindowSize
    
    let availableSizes: [WindowSize] = [
        WindowSize(width: 360, height: 660),
        WindowSize(width: 420, height: 800),
        WindowSize(width: 880, height: 660),
        WindowSize(width: 1200, height: 800)
    ]
    
    private init() {
        // 从 UserDefaults 读取保存的尺寸，如果没有则使用默认尺寸
        if let savedWidth = UserDefaults.standard.object(forKey: "windowWidth") as? Double,
           let savedHeight = UserDefaults.standard.object(forKey: "windowHeight") as? Double {
            selectedSize = WindowSize(width: savedWidth, height: savedHeight)
        } else {
            // 默认尺寸 420x800
            selectedSize = WindowSize(width: 420, height: 800)
        }
    }
    
    func saveWindowSize(_ size: WindowSize) {
        selectedSize = size
        UserDefaults.standard.set(size.width, forKey: "windowWidth")
        UserDefaults.standard.set(size.height, forKey: "windowHeight")
    }
}

struct WindowSize: Identifiable, Equatable {
    let id = UUID()
    let width: Double
    let height: Double
    
    static func == (lhs: WindowSize, rhs: WindowSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    var title: String {
        "\(Int(width)) x \(Int(height))"
    }
    
}
