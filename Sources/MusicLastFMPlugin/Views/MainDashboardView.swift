import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var manager: ScrobblerManager
    @State private var selection: SidebarItem? = .profile
    enum SidebarItem: Hashable { case profile, recent, topArtists, topAlbums }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Me") {
                    NavigationLink(value: SidebarItem.profile) { Label("Profile", systemImage: "person.fill") }
                }
                Section("Library") {
                    NavigationLink(value: SidebarItem.recent) { Label("Recent Tracks", systemImage: "music.note.list") }
                    NavigationLink(value: SidebarItem.topArtists) { Label("Top Artists", systemImage: "music.mic") }
                    NavigationLink(value: SidebarItem.topAlbums) { Label("Top Albums", systemImage: "square.stack.fill") }
                }
            }
            .navigationTitle("Last.fm")
            .listStyle(SidebarListStyle())
            
            VStack {
                Spacer()
                if manager.isRunning {
                    HStack {
                        Image(systemName: "waveform").foregroundColor(.lastFmRed)
                        Text(manager.localNowPlaying != nil ? "Scrobbling" : "Waiting for Music...").font(.caption).fontWeight(.bold)
                    }.padding(.bottom, 8)
                } else {
                    Button("Start Scrobbler") { manager.start() }.buttonStyle(.bordered).padding(.bottom, 8)
                }
                Button(action: { manager.logout() }) {
                    HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Logout") }.foregroundColor(.secondary)
                }.buttonStyle(.plain).padding(.bottom)
            }
        } detail: {
            NavigationStack {
                switch selection {
                case .profile: ProfileView(manager: manager)
                case .recent: RecentTracksView(manager: manager)
                case .topArtists: TopArtistsView(manager: manager)
                case .topAlbums: TopAlbumsView(manager: manager)
                case .none: Text("Select an item")
                }
            }
            .navigationDestination(for: UserInfo.self) { user in
                UserDetailView(username: user.username, manager: manager)
            }
            .navigationDestination(for: ScrobbledTrack.self) { track in
                TrackDetailView(track: track, manager: manager)
            }
        }
    }
}
