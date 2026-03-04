import SwiftUI

struct ArtistDetailView: View {
    let artist: TopArtist
    @ObservedObject var manager: ScrobblerManager
    let id: String
    
    init(artist: TopArtist, manager: ScrobblerManager) {
        self.artist = artist
        self.manager = manager
        self.id = "artist_\(artist.name)"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HeroHeaderView(title: artist.name, subtitle: "Artist", statValue: "\(artist.playcount)", statLabel: "Scrobbles", imageURL: artist.imageURL, fallbackIcon: "music.mic", isCircular: true)
                VStack(alignment: .leading) {
                    if let details = manager.entityDetails[id] {
                        DescriptionBoxView(text: details.description)
                        SimilarGridArtistView(artists: details.similarArtists)
                    } else {
                        ProgressView("Loading info...").padding()
                    }
                }.padding(.horizontal, 30)
            }
        }.edgesIgnoringSafeArea(.top)
        .onAppear { manager.fetchInfo(for: "artist", artist: artist.name, id: id) }
    }
}
