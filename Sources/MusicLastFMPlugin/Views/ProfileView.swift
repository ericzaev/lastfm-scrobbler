import SwiftUI

struct ProfileView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        ScrollView {
            if manager.isFetchingData {
                ProgressView().padding(.top, 100)
            } else if let profile = manager.profile {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Profile Hero
                    ZStack(alignment: .bottomLeading) {
                        Color.lastFmRed.edgesIgnoringSafeArea(.top)
                        HStack(alignment: .bottom, spacing: 20) {
                            CachedAsyncImage(url: profile.avatarURL, fallbackIcon: "person.fill", shape: AnyShape(Circle()))
                                .frame(width: 140, height: 140)
                                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                .shadow(radius: 5)
                                .padding(.leading, 30)
                                .padding(.bottom, -20)
                            
                            VStack(alignment: .leading) {
                                Text(profile.realName).font(.system(size: 32, weight: .black)).foregroundColor(.white)
                                Text(profile.username).font(.title3).foregroundColor(Color(white: 0.9))
                            }.padding(.bottom, 10)
                            Spacer()
                        }
                    }
                    .frame(height: 200)
                    .padding(.bottom, 40)
                    
                    // Stats Bar
                    HStack(spacing: 40) {
                        VStack(alignment: .leading) {
                            Text("\(profile.playcount)").font(.title).fontWeight(.bold)
                            Text("Scrobbles").font(.caption).foregroundColor(.secondary).textCase(.uppercase)
                        }
                        VStack(alignment: .leading) {
                            Text(profile.registered, style: .date).font(.title2).fontWeight(.bold)
                            Text("Registered").font(.caption).foregroundColor(.secondary).textCase(.uppercase)
                        }
                        Spacer()
                        Button(action: { manager.fetchLiveData() }) {
                            Image(systemName: "arrow.clockwise")
                        }.buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    
                    Divider()
                    
                    if let nowPlaying = manager.localNowPlaying {
                        NowPlayingStatusView(track: nowPlaying)
                    } else {
                        VStack {
                            Text("Nothing playing right now").font(.headline).foregroundColor(.secondary)
                            Text("Open the Music app to start scrobbling.").font(.subheadline).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(NSColor.controlBackgroundColor))
                        Divider()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Recent Tracks").font(.title2).fontWeight(.bold).padding(.top, 20).padding(.bottom, 10)
                        ForEach(manager.recentTracks.filter { $0.timestamp != nil }.prefix(5)) { track in
                            NavigationLink(value: track) {
                                HStack {
                                    CachedAsyncImage(url: track.imageURL, fallbackIcon: "music.note", shape: AnyShape(Rectangle()))
                                        .frame(width: 50, height: 50)
                                    VStack(alignment: .leading) {
                                        Text(track.name).fontWeight(.semibold)
                                        Text(track.artist).font(.subheadline).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }.padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 30)
                    
                }
            }
        }
        .edgesIgnoringSafeArea(.top)
    }
}
