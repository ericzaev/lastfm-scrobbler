import SwiftUI

@main
struct MusicLastFMApp: App {
    @StateObject private var scrobblerManager = ScrobblerManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("MusicLastFM", id: "main") {
            ContentView()
                .environmentObject(scrobblerManager)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            if let track = scrobblerManager.localNowPlaying {
                Text("Now Playing:")
                    .font(.caption)
                Text("\(track.name) — \(track.artist)")
                    .fontWeight(.bold)
                Divider()
            }
            
            Button(scrobblerManager.isRunning ? "Stop Scrobbling" : "Start Scrobbling") {
                if scrobblerManager.isRunning {
                    scrobblerManager.stop()
                } else {
                    scrobblerManager.start()
                }
            }
            
            Divider()
            
            Button("Open MusicLastFM") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: scrobblerManager.isRunning ? "music.note" : "music.note.list")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
