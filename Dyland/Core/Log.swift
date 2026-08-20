import Foundation
import OSLog

/// Central logging facade.
///
/// Every subsystem gets its own `Logger` category so `log stream --predicate
/// 'subsystem == "com.gerdoo.dyland"'` can be filtered per module. Nothing in
/// this app swallows an error silently: a `catch` either recovers in a way the
/// user can see, or it lands here at `.error`.
enum Log {
    private static let subsystem = "com.gerdoo.dyland"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let notch = Logger(subsystem: subsystem, category: "notch")
    static let media = Logger(subsystem: subsystem, category: "media")
    static let shelf = Logger(subsystem: subsystem, category: "shelf")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let actions = Logger(subsystem: subsystem, category: "actions")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
