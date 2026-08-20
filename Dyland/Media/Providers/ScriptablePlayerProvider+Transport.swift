import Foundation

/// Playback control.
///
/// Every command is a no-op when the target application is not running: Dyland
/// must never launch a music app on the user's behalf just because they pressed
/// play in the notch. Commands are also the operations that genuinely need
/// Automation permission, so a refusal is reported once and then tolerated.
extension ScriptablePlayerProvider {

    func play() async { await command("play") }
    func pause() async { await command("pause") }
    func togglePlayPause() async { await command("playpause") }
    func nextTrack() async { await command("next track") }
    func previousTrack() async { await command("previous track") }

    private func command(_ verb: String) async {
        guard isRunning else {
            Log.media.notice("Ignoring \(verb, privacy: .public): \(self.configuration.displayName, privacy: .public) is not running")
            return
        }
        do {
            try await runner.run(Scripts.command(verb, for: configuration))
            await refresh()
        } catch AppleScriptRunner.Failure.permissionDenied {
            warnAboutPermissionOnce()
        } catch {
            Log.media.error("\(self.configuration.displayName, privacy: .public) command '\(verb, privacy: .public)' failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
