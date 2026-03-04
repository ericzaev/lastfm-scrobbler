import Foundation
import AppKit

class MusicMonitor {
    static func getCurrentTrack() -> Track? {
        let script = """
        tell application "System Events"
            if not (exists process "Music") then return ""
        end tell
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration
            end if
        end tell
        return ""
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let stringValue = result.stringValue, !stringValue.isEmpty {
                let parts = stringValue.components(separatedBy: "|||")
                if parts.count == 4 {
                    return Track(name: parts[0], artist: parts[1], album: parts[2], duration: Double(parts[3]))
                }
            }
        }
        return nil
    }
}
