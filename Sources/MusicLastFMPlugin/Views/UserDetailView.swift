import SwiftUI

struct UserDetailView: View {
    let username: String
    @ObservedObject var manager: ScrobblerManager
    
    var body: some View {
        ScrollView {
            if let profile = manager.otherProfiles[username] {
                VStack(alignment: .leading, spacing: 0) {
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
                    }
                    .padding(.horizontal, 30)
                }
            } else {
                ProgressView().padding(.top, 100)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear { manager.fetchOtherProfile(username: username) }
    }
}
