import Foundation

/// Runs AppleScript off the main thread on a single serial queue.
///
/// Why AppleScript at all: it is the only *public* way to read what Music or
/// Spotify is playing (see `MediaProvider` for why MediaRemote is out).
///
/// Why a dedicated serial queue: `NSAppleScript` is not thread-safe, and
/// executing one blocks its thread for as long as the target app takes to
/// answer. Compiled scripts are cached because compilation is the expensive
/// part; execution of a cached script is sub-millisecond in the common case.
final class AppleScriptRunner: @unchecked Sendable {

    enum Failure: Error, Equatable {
        /// The target application is not running. Never treated as an error the
        /// user should see — Dyland must not launch a music app on its own.
        case targetNotRunning
        /// The user has not granted (or has revoked) Automation access.
        case permissionDenied
        case executionFailed(code: Int, message: String)
        case compilationFailed(String)
    }

    private let queue = DispatchQueue(label: "com.gerdoo.dyland.applescript", qos: .userInitiated)
    private var compiled: [String: NSAppleScript] = [:]

    /// AppleEvent error codes worth distinguishing.
    private enum OSAError {
        static let procNotFound = -600      // application isn't running
        static let appNotRunning = -609
        static let eventNotPermitted = -1743 // Automation permission refused
        static let timedOut = -1712
    }

    func run(_ source: String) async throws -> NSAppleEventDescriptor {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.execute(source))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Convenience for scripts that return a string.
    func runReturningString(_ source: String) async throws -> String {
        try await run(source).stringValue ?? ""
    }

    private func execute(_ source: String) throws -> NSAppleEventDescriptor {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let created = NSAppleScript(source: source) else {
                throw Failure.compilationFailed(source)
            }
            var compileError: NSDictionary?
            guard created.compileAndReturnError(&compileError) else {
                throw Failure.compilationFailed(Self.message(from: compileError))
            }
            compiled[source] = created
            script = created
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            switch code {
            case OSAError.procNotFound, OSAError.appNotRunning:
                throw Failure.targetNotRunning
            case OSAError.eventNotPermitted:
                throw Failure.permissionDenied
            default:
                throw Failure.executionFailed(code: code, message: Self.message(from: error))
            }
        }

        return result
    }

    private static func message(from error: NSDictionary?) -> String {
        (error?[NSAppleScript.errorMessage] as? String) ?? "unknown AppleScript error"
    }
}
