import SwiftUI

struct NowPlayingStatusView: View {
    let track: Track
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Color.lastFmGray
                    Image(systemName: "music.note").font(.title).foregroundColor(.gray)
                }
                .frame(width: 80, height: 80)
                .cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                        Text("Scrobbling now").font(.caption).fontWeight(.bold).textCase(.uppercase)
                    }
                    .foregroundColor(.lastFmRed)
                    
                    Text(track.name).font(.title3).fontWeight(.bold).foregroundColor(.primary)
                    Text(track.artist).font(.body).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
        }
    }
}
