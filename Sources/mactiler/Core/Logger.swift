import Foundation

enum Logger {
    static func log(_ message: String, file: String = #file, function: String = #function) {
        let filename = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        print("[\(filename)] \(message)")
    }

    static func action(_ action: String) {
        print("→ \(action)")
    }

    static func error(_ message: String) {
        print("✗ ERROR: \(message)")
    }

    static func success(_ message: String) {
        print("✓ \(message)")
    }
}
