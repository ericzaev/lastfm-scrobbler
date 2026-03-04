import SwiftUI

struct TrackDetailView: View {
    let track: ScrobbledTrack
    @ObservedObject var manager: ScrobblerManager
    let id: String
    
    init(track: ScrobbledTrack, manager: ScrobblerManager) {
        self.track = track
        self.manager = manager
        self.id = "track_\(track.artist)_\(track.name)"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HeroHeaderView(title: track.name, subtitle: track.artist, statValue: track.timestamp != nil ? "1" : "Listening Now", statLabel: "Scrobbles", imageURL: track.imageURL, fallbackIcon: "music.note", isCircular: false)
                VStack(alignment: .leading) {
                    Text("Album: \(track.album)").font(.headline).foregroundColor(.secondary)
                    
                    if let details = manager.entityDetails[id] {
                        DescriptionBoxView(text: details.description)
                        SimilarGridTrackView(tracks: details.similarTracks)
                    } else {
                        ProgressView("Loading info...").padding()
                    }
                    
                }.padding(.horizontal, 30)
            }
        }.edgesIgnoringSafeArea(.top)
        .onAppear { manager.fetchInfo(for: "track", artist: track.artist, track: track.name, id: id) }
    }
}
