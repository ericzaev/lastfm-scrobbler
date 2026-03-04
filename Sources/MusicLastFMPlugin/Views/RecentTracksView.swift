import SwiftUI

struct RecentTracksView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent Tracks").font(.largeTitle).fontWeight(.black).padding(.horizontal).padding(.top).padding(.bottom)
                
                if manager.isFetchingData {
                    ProgressView().padding()
                } else {
                    if let nowPlaying = manager.localNowPlaying {
                        NowPlayingStatusView(track: nowPlaying)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(manager.recentTracks.filter { $0.timestamp != nil }) { track in
                            NavigationLink(value: track) {
                                HStack(spacing: 16) {
                                    CachedAsyncImage(url: track.imageURL, fallbackIcon: "music.note", shape: AnyShape(Rectangle()))
                                        .frame(width: 60, height: 60)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.name).fontWeight(.bold).foregroundColor(.primary)
                                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let date = track.timestamp {
                                        Text(date, style: .relative).font(.caption).foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal).padding(.vertical, 8).background(Color(NSColor.controlBackgroundColor))
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 90)
                        }
                    }
                }
            }
        }
        .toolbar { Button(action: { manager.fetchLiveData() }) { Image(systemName: "arrow.clockwise") } }
    }
}
