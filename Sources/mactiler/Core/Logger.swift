import Foundation
import os

enum Logger {
    private static let logger = os.Logger(subsystem: "com.mactiler.app", category: "general")

    static func log(_ message: String, file: String = #file) {
        let filename = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        logger.info("[\(filename, privacy: .public)] \(message, privacy: .public)")
    }

    static func action(_ action: String) {
        logger.info("→ \(action, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("✗ ERROR: \(message, privacy: .public)")
    }

    static func success(_ message: String) {
        logger.info("✓ \(message, privacy: .public)")
    }
}
