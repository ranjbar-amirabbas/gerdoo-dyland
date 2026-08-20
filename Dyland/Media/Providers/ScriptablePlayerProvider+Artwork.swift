import AppKit
import Foundation

/// Artwork retrieval, split out because the two players deliver it in
/// completely different ways: Music hands over the embedded image bytes, while
/// Spotify returns an https URL that has to be fetched.
///
/// Missing artwork is a normal outcome everywhere here — a track genuinely may
/// not have any — so every failure path returns `nil` rather than throwing.
extension ScriptablePlayerProvider {

    func artwork(for track: MediaTrack) async -> NSImage? {
        guard isRunning else { return nil }
        switch configuration.artworkSource {
        case .unavailable:
            return nil
        case .embeddedData:
            return await embeddedArtwork()
        case .remoteURL:
            return await remoteArtwork()
        }
    }

    private func embeddedArtwork() async -> NSImage? {
        do {
            let descriptor = try await runner.run(Scripts.artwork(for: configuration))
            guard let data = descriptor.data as Data?, !data.isEmpty else { return nil }
            return NSImage(data: data)
        } catch AppleScriptRunner.Failure.permissionDenied {
            warnAboutPermissionOnce()
            return nil
        } catch {
            Log.media.debug("No embedded artwork available from \(self.configuration.displayName, privacy: .public)")
            return nil
        }
    }

    private func remoteArtwork() async -> NSImage? {
        do {
            let raw = try await runner.runReturningString(Scripts.artwork(for: configuration))
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed), url.scheme == "https" else { return nil }
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch AppleScriptRunner.Failure.permissionDenied {
            warnAboutPermissionOnce()
            return nil
        } catch {
            Log.media.debug("Artwork fetch failed for \(self.configuration.displayName, privacy: .public)")
            return nil
        }
    }
}
