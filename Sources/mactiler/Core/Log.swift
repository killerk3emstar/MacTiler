import os

/// Thin wrapper over os.Logger. View with:
///   log stream --predicate 'subsystem == "com.mactiler.app"' --level info
///
/// Messages are public, so never log window titles or other user content;
/// identify windows by their numeric id.
enum Log {
    private static let logger = os.Logger(subsystem: "com.mactiler.app", category: "general")

    static func info(_ message: String, file: StaticString = #fileID) {
        logger.info("[\(source(file), privacy: .public)] \(message, privacy: .public)")
    }

    static func error(_ message: String, file: StaticString = #fileID) {
        logger.error("[\(source(file), privacy: .public)] \(message, privacy: .public)")
    }

    private static func source(_ file: StaticString) -> String {
        let path = "\(file)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return name.replacingOccurrences(of: ".swift", with: "")
    }
}
