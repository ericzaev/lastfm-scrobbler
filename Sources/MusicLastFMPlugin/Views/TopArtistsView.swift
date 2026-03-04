import SwiftUI

struct TopArtistsView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        EntityGridView(items: manager.topArtists, title: "Top Artists", fallbackIcon: "music.mic", isCircular: true,
                       getName: { $0.name }, getSubtitle: { _ in nil }, getCount: { $0.playcount }, getURL: { $0.imageURL })
        .navigationDestination(for: TopArtist.self) { artist in ArtistDetailView(artist: artist, manager: manager) }
    }
}
