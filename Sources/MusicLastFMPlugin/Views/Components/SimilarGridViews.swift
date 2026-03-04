import SwiftUI

struct SimilarGridArtistView: View {
    let artists: [TopArtist]
    var body: some View {
        if !artists.isEmpty {
            VStack(alignment: .leading) {
                Text("Similar Artists").font(.title2).fontWeight(.bold).padding(.top)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(artists) { artist in
                            VStack {
                                CachedAsyncImage(url: artist.imageURL, fallbackIcon: "music.mic", shape: AnyShape(Circle()))
                                    .frame(width: 100, height: 100)
                                Text(artist.name).font(.subheadline).lineLimit(1).frame(width: 100)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SimilarGridTrackView: View {
    let tracks: [ScrobbledTrack]
    var body: some View {
        if !tracks.isEmpty {
            VStack(alignment: .leading) {
                Text("Similar Tracks").font(.title2).fontWeight(.bold).padding(.top)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(tracks) { track in
                            VStack(alignment: .leading) {
                                CachedAsyncImage(url: track.imageURL, fallbackIcon: "music.note", shape: AnyShape(Rectangle()))
                                    .frame(width: 120, height: 120).cornerRadius(8)
                                Text(track.name).font(.subheadline).fontWeight(.bold).lineLimit(1).frame(width: 120, alignment: .leading)
                                Text(track.artist).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: 120, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }
}
