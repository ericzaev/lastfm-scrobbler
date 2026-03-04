import SwiftUI

struct TopAlbumsView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        EntityGridView(items: manager.topAlbums, title: "Top Albums", fallbackIcon: "square.stack.fill", isCircular: false,
                       getName: { $0.name }, getSubtitle: { $0.artist }, getCount: { $0.playcount }, getURL: { $0.imageURL })
        .navigationDestination(for: TopAlbum.self) { album in AlbumDetailView(album: album, manager: manager) }
    }
}
