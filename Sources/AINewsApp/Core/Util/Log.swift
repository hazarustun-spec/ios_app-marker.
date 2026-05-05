import Foundation
import Sentry

// MARK: - Logger
// DEBUG'da console'a yazar; Production'da Sentry'e gönderir.
enum Log {
    static func debug(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        #if DEBUG
        Swift.print("[\(file):\(line)] \(message())")
        #endif
    }

    static func error(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let msg = message()
        #if DEBUG
        Swift.print("⚠️ [\(file):\(line)] \(msg)")
        #else
        SentrySDK.capture(message: msg) { scope in
            scope.setTag(value: "\(file):\(line)", key: "source")
        }
        #endif
    }
}
