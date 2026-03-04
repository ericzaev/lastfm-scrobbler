import SwiftUI

struct AlbumDetailView: View {
    let album: TopAlbum
    @ObservedObject var manager: ScrobblerManager
    let id: String
    
    init(album: TopAlbum, manager: ScrobblerManager) {
        self.album = album
        self.manager = manager
        self.id = "album_\(album.artist)_\(album.name)"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HeroHeaderView(title: album.name, subtitle: album.artist, statValue: "\(album.playcount)", statLabel: "Scrobbles", imageURL: album.imageURL, fallbackIcon: "square.stack.fill", isCircular: false)
                VStack(alignment: .leading) {
                    if let details = manager.entityDetails[id] {
                        DescriptionBoxView(text: details.description)
                    } else {
                        ProgressView("Loading info...").padding()
                    }
                }.padding(.horizontal, 30)
            }
        }.edgesIgnoringSafeArea(.top)
        .onAppear { manager.fetchInfo(for: "album", artist: album.artist, album: album.name, id: id) }
    }
}
