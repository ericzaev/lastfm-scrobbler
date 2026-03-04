import SwiftUI
import Foundation
import CryptoKit
import AppKit

// MARK: - Brand Colors
extension Color {
    static let lastFmRed = Color(red: 0.725, green: 0.0, blue: 0.0)
    static let lastFmDark = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let lastFmGray = Color(white: 0.95)
}

// MARK: - Crypto Helper
extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // Strip basic HTML tags
    func stripHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

// MARK: - Models
struct Track: Equatable {
    var name: String; var artist: String; var album: String; var duration: Double? = nil
}
struct UserProfile {
    var username: String; var realName: String; var playcount: Int; var registered: Date; var avatarURL: URL?
}
struct ScrobbledTrack: Identifiable, Hashable {
    let id = UUID(); let name: String; let artist: String; let album: String; let timestamp: Date?; let imageURL: URL?
}
struct TopArtist: Identifiable, Hashable {
    let id = UUID(); let name: String; let playcount: Int; let imageURL: URL?
}
struct TopAlbum: Identifiable, Hashable {
    let id = UUID(); let name: String; let artist: String; let playcount: Int; let imageURL: URL?
}

struct UserInfo: Identifiable, Hashable {
    let id = UUID(); let username: String
}

// Detail Models
struct EntityDetails {
    var description: String?
    var similarArtists: [TopArtist] = []
    var similarTracks: [ScrobbledTrack] = []
}

// MARK: - Last.fm API Response Decodables
struct LFMImage: Decodable {
    let size: String; let url: String
    enum CodingKeys: String, CodingKey { case size; case url = "#text" }
}

struct LFMWiki: Decodable {
    let summary: String?
    let content: String?
}

struct LFMUserResponse: Decodable {
    struct User: Decodable {
        let name: String; let realname: String?; let playcount: String; let image: [LFMImage]?; let registered: Registered
        struct Registered: Decodable { let unixtime: String }
    }
    let user: User
}
struct LFMRecentTracksResponse: Decodable {
    struct RecentTracks: Decodable {
        struct Track: Decodable {
            struct Artist: Decodable { let name: String; enum CodingKeys: String, CodingKey { case name = "#text" } }
            struct Album: Decodable { let title: String; enum CodingKeys: String, CodingKey { case title = "#text" } }
            struct DateObj: Decodable { let uts: String }
            struct Attr: Decodable { let nowplaying: String?; enum CodingKeys: String, CodingKey { case nowplaying = "nowplaying" } }
            let name: String; let artist: Artist; let album: Album; let date: DateObj?; let image: [LFMImage]?; let attr: Attr?
            enum CodingKeys: String, CodingKey { case name, artist, album, date, image; case attr = "@attr" }
        }
        let track: [Track]
    }
    let recenttracks: RecentTracks
}
struct LFMTopArtistsResponse: Decodable {
    struct TopArtists: Decodable {
        struct Artist: Decodable { let name: String; let playcount: String; let image: [LFMImage]? }
        let artist: [Artist]
    }
    let topartists: TopArtists
}
struct LFMTopAlbumsResponse: Decodable {
    struct TopAlbums: Decodable {
        struct Album: Decodable {
            struct Artist: Decodable { let name: String }
            let name: String; let playcount: String; let artist: Artist; let image: [LFMImage]?
        }
        let album: [Album]
    }
    let topalbums: TopAlbums
}

// Info Decodables
struct LFMArtistInfoResponse: Decodable {
    struct Artist: Decodable {
        let name: String
        let bio: LFMWiki?
        struct Similar: Decodable {
            struct SArtist: Decodable { let name: String; let image: [LFMImage]? }
            let artist: [SArtist]?
        }
        let similar: Similar?
    }
    let artist: Artist
}

struct LFMTrackInfoResponse: Decodable {
    struct TrackInfo: Decodable {
        let name: String
        let wiki: LFMWiki?
        struct Similar: Decodable {
            struct STrack: Decodable { let name: String; struct Art: Decodable { let name: String }; let artist: Art; let image: [LFMImage]? }
            let track: [STrack]?
        }
        let similar: Similar?
    }
    let track: TrackInfo
}

struct LFMAlbumInfoResponse: Decodable {
    struct AlbumInfo: Decodable {
        let name: String
        let wiki: LFMWiki?
    }
    let album: AlbumInfo
}

// MARK: - Manager
@MainActor
class ScrobblerManager: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isRunning = false
    @Published var lastScrobbledTrack: String = ""
    @Published var isFetchingData = false
    
    // Auth info from AppStorage (persistent)
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("apiSecret") var apiSecret: String = ""
    
    @AppStorage("sessionKey") var sessionKey: String = ""
    @AppStorage("username") var username: String = ""
    @AppStorage("isAuthenticated") var isAuthenticated: Bool = false
    
    @Published var isAwaitingWebApproval = false
    private var currentAuthToken = ""
    
    @Published var profile: UserProfile?
    @Published var recentTracks: [ScrobbledTrack] = []
    @Published var topArtists: [TopArtist] = []
    @Published var topAlbums: [TopAlbum] = []
    
    @Published var entityDetails: [String: EntityDetails] = [:]
    @Published var otherProfiles: [String: UserProfile] = [:]
    
    @Published var localNowPlaying: Track?
    private var scrobbleTask: Task<Void, Never>?
    private var currentTrackStartTime: Date?
    private var lastTrackObj: Track?
    
    init() {
        if isAuthenticated { fetchLiveData(); start() }
    }
    
    var hasValidCredentials: Bool { return !apiKey.isEmpty && !apiSecret.isEmpty }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        scrobbleTask = Task {
            while !Task.isCancelled {
                await checkTrack()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    
    func stop() { isRunning = false; scrobbleTask?.cancel(); scrobbleTask = nil; localNowPlaying = nil }
    
    private func checkTrack() async {
        let script = """
        tell application "System Events"
            if not (exists process "Music") then return ""
        end tell
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration
            end if
        end tell
        return ""
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let stringValue = result.stringValue, !stringValue.isEmpty {
                let parts = stringValue.components(separatedBy: "|||")
                if parts.count == 4 {
                    let track = Track(name: parts[0], artist: parts[1], album: parts[2], duration: Double(parts[3]))
                    self.localNowPlaying = track
                    let trackId = "\(track.artist)-\(track.name)"
                    
                    if trackId != lastScrobbledTrack {
                        if let lastObj = lastTrackObj, let startTime = currentTrackStartTime {
                            let playedTime = Date().timeIntervalSince(startTime)
                            let requiredTime = min(240.0, (lastObj.duration ?? 0.0) / 2.0)
                            if playedTime >= (requiredTime > 0 ? requiredTime : 30.0) {
                                sendScrobbleToAPI(track: lastObj, timestamp: startTime)
                            }
                        }
                        
                        sendNowPlayingToAPI(track: track)
                        currentTrackStartTime = Date()
                        lastTrackObj = track
                        
                        scrobbleLocal(track: track)
                        lastScrobbledTrack = trackId
                    }
                }
            } else { 
                self.localNowPlaying = nil 
            }
        }
    }
    
    private func scrobbleLocal(track: Track) {
        guard isAuthenticated else { return }
        recentTracks.removeAll { $0.timestamp == nil }
        let newScrobble = ScrobbledTrack(name: track.name, artist: track.artist, album: track.album, timestamp: nil, imageURL: nil)
        recentTracks.insert(newScrobble, at: 0)
    }
    
    private func generateSignature(params: [String: String], secret: String) -> String {
        let sortedKeys = params.keys.sorted()
        var sigString = ""
        for key in sortedKeys {
            sigString += "\(key)\(params[key]!)"
        }
        sigString += secret
        return sigString.md5
    }
    
    private func sendNowPlayingToAPI(track: Track) {
        guard isAuthenticated, !sessionKey.isEmpty else { return }
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.name,
            "album": track.album,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        params["api_sig"] = generateSignature(params: params, secret: apiSecret)
        
        Task {
            guard let url = URL(string: "https://ws.audioscrobbler.com/2.0/") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            var components = URLComponents()
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let _ = try? await URLSession.shared.data(for: request)
        }
    }
    
    private func sendScrobbleToAPI(track: Track, timestamp: Date) {
        guard isAuthenticated, !sessionKey.isEmpty else { return }
        let timeString = String(Int(timestamp.timeIntervalSince1970))
        var params: [String: String] = [
            "method": "track.scrobble",
            "artist[0]": track.artist,
            "track[0]": track.name,
            "album[0]": track.album,
            "timestamp[0]": timeString,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        params["api_sig"] = generateSignature(params: params, secret: apiSecret)
        
        Task {
            guard let url = URL(string: "https://ws.audioscrobbler.com/2.0/") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            var components = URLComponents()
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let _ = try? await URLSession.shared.data(for: request)
            
            // Refresh recent tracks to reflect new scrobble
            fetchLiveData()
        }
    }
    
    func beginWebAuth() {
        guard hasValidCredentials, !apiSecret.isEmpty else { return }
        Task {
            do {
                let sigString = "api_key\(apiKey)methodauth.getToken\(apiSecret)"
                let sig = sigString.md5
                let urlString = "https://ws.audioscrobbler.com/2.0/?method=auth.getToken&api_key=\(apiKey)&api_sig=\(sig)&format=json"
                guard let url = URL(string: urlString) else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                struct TokenResponse: Decodable { let token: String? }
                let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                if let token = response.token {
                    DispatchQueue.main.async {
                        self.currentAuthToken = token; self.isAwaitingWebApproval = true
                        if let authURL = URL(string: "https://www.last.fm/api/auth/?api_key=\(self.apiKey)&token=\(token)") {
                            NSWorkspace.shared.open(authURL)
                        }
                    }
                }
            } catch { print("Auth error: \(error)") }
        }
    }
    
    func completeWebAuth() {
        guard hasValidCredentials, !currentAuthToken.isEmpty else { return }
        Task {
            do {
                let sigString = "api_key\(apiKey)methodauth.getSessiontoken\(currentAuthToken)\(apiSecret)"
                let sig = sigString.md5
                let urlString = "https://ws.audioscrobbler.com/2.0/?method=auth.getSession&api_key=\(apiKey)&token=\(currentAuthToken)&api_sig=\(sig)&format=json"
                guard let url = URL(string: urlString) else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                struct SessionResponse: Decodable {
                    struct Session: Decodable { let name: String; let key: String }
                    let session: Session?; let message: String?
                }
                let response = try JSONDecoder().decode(SessionResponse.self, from: data)
                DispatchQueue.main.async {
                    if let session = response.session {
                        self.username = session.name; self.sessionKey = session.key; self.isAuthenticated = true
                        self.isAwaitingWebApproval = false; self.fetchLiveData(); self.start()
                    } else { self.isAwaitingWebApproval = false }
                }
            } catch { DispatchQueue.main.async { self.isAwaitingWebApproval = false } }
        }
    }
    
    func logout() {
        stop(); isAuthenticated = false; sessionKey = ""; currentAuthToken = ""; isAwaitingWebApproval = false
        profile = nil; recentTracks = []; topArtists = []; topAlbums = []; localNowPlaying = nil
    }
    
    func fetchLiveData() {
        guard isAuthenticated, !username.isEmpty, hasValidCredentials else { return }
        isFetchingData = true
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchProfile() }
                group.addTask { await self.fetchRecentTracks() }
                group.addTask { await self.fetchTopArtists() }
                group.addTask { await self.fetchTopAlbums() }
            }
            DispatchQueue.main.async { self.isFetchingData = false }
        }
    }
    
    private func fetchProfile() async {
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=user.getinfo&user=\(username)&api_key=\(apiKey)&format=json"
        guard let url = URL(string: urlString), let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let res = try? JSONDecoder().decode(LFMUserResponse.self, from: data) {
            let u = res.user
            let avatarUrlStr = u.image?.first(where: { $0.size == "extralarge" })?.url ?? u.image?.last?.url
            DispatchQueue.main.async {
                self.profile = UserProfile(username: u.name, realName: u.realname ?? u.name, playcount: Int(u.playcount) ?? 0, registered: Date(timeIntervalSince1970: TimeInterval(u.registered.unixtime) ?? 0), avatarURL: avatarUrlStr != nil && !avatarUrlStr!.isEmpty ? URL(string: avatarUrlStr!) : nil)
            }
        }
    }
    
    func fetchOtherProfile(username: String) {
        Task {
            let urlString = "https://ws.audioscrobbler.com/2.0/?method=user.getinfo&user=\(username)&api_key=\(apiKey)&format=json"
            guard let url = URL(string: urlString), let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            if let res = try? JSONDecoder().decode(LFMUserResponse.self, from: data) {
                let u = res.user
                let avatarUrlStr = u.image?.first(where: { $0.size == "extralarge" })?.url ?? u.image?.last?.url
                let p = UserProfile(username: u.name, realName: u.realname ?? u.name, playcount: Int(u.playcount) ?? 0, registered: Date(timeIntervalSince1970: TimeInterval(u.registered.unixtime) ?? 0), avatarURL: avatarUrlStr != nil && !avatarUrlStr!.isEmpty ? URL(string: avatarUrlStr!) : nil)
                DispatchQueue.main.async { self.otherProfiles[username] = p }
            }
        }
    }
    
    private func fetchRecentTracks() async {
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=\(username)&api_key=\(apiKey)&limit=50&format=json"
        guard let url = URL(string: urlString), let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let res = try? JSONDecoder().decode(LFMRecentTracksResponse.self, from: data) {
            let tracks = res.recenttracks.track.map { t -> ScrobbledTrack in
                var d: Date? = nil
                if t.attr?.nowplaying != "true" {
                    if let uts = t.date?.uts, let time = TimeInterval(uts) { d = Date(timeIntervalSince1970: time) }
                }
                let imgUrlStr = t.image?.first(where: { $0.size == "extralarge" })?.url ?? t.image?.last?.url
                return ScrobbledTrack(name: t.name, artist: t.artist.name, album: t.album.title, timestamp: d, imageURL: imgUrlStr != nil && !imgUrlStr!.isEmpty ? URL(string: imgUrlStr!) : nil)
            }
            DispatchQueue.main.async { self.recentTracks = tracks }
        }
    }
    
    private func fetchTopArtists() async {
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=user.gettopartists&user=\(username)&api_key=\(apiKey)&limit=50&format=json"
        guard let url = URL(string: urlString), let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let res = try? JSONDecoder().decode(LFMTopArtistsResponse.self, from: data) {
            let artists = res.topartists.artist.map { a -> TopArtist in
                let imgUrlStr = a.image?.first(where: { $0.size == "extralarge" })?.url ?? a.image?.last?.url
                return TopArtist(name: a.name, playcount: Int(a.playcount) ?? 0, imageURL: imgUrlStr != nil && !imgUrlStr!.isEmpty ? URL(string: imgUrlStr!) : nil)
            }
            DispatchQueue.main.async { self.topArtists = artists }
        }
    }
    
    private func fetchTopAlbums() async {
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=user.gettopalbums&user=\(username)&api_key=\(apiKey)&limit=50&format=json"
        guard let url = URL(string: urlString), let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let res = try? JSONDecoder().decode(LFMTopAlbumsResponse.self, from: data) {
            let albums = res.topalbums.album.map { a -> TopAlbum in
                let imgUrlStr = a.image?.first(where: { $0.size == "extralarge" })?.url ?? a.image?.last?.url
                return TopAlbum(name: a.name, artist: a.artist.name, playcount: Int(a.playcount) ?? 0, imageURL: imgUrlStr != nil && !imgUrlStr!.isEmpty ? URL(string: imgUrlStr!) : nil)
            }
            DispatchQueue.main.async { self.topAlbums = albums }
        }
    }
    
    func fetchInfo(for urlType: String, artist: String, track: String? = nil, album: String? = nil, id: String) {
        Task {
            var urlString = ""
            let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if urlType == "artist" {
                urlString = "https://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=\(encodedArtist)&api_key=\(apiKey)&format=json"
            } else if urlType == "track" {
                let encodedTrack = track?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                urlString = "https://ws.audioscrobbler.com/2.0/?method=track.getinfo&artist=\(encodedArtist)&track=\(encodedTrack)&api_key=\(apiKey)&format=json"
            } else if urlType == "album" {
                let encodedAlbum = album?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                urlString = "https://ws.audioscrobbler.com/2.0/?method=album.getinfo&artist=\(encodedArtist)&album=\(encodedAlbum)&api_key=\(apiKey)&format=json"
            }
            
            var fetchedDetails = EntityDetails()
            if let apiURL = URL(string: urlString), let (data, _) = try? await URLSession.shared.data(from: apiURL) {
                if urlType == "artist", let res = try? JSONDecoder().decode(LFMArtistInfoResponse.self, from: data) {
                    fetchedDetails.description = res.artist.bio?.summary?.stripHTML()
                    if let similar = res.artist.similar?.artist {
                        fetchedDetails.similarArtists = similar.map {
                            TopArtist(name: $0.name, playcount: 0, imageURL: URL(string: $0.image?.last?.url ?? ""))
                        }
                    }
                } else if urlType == "track", let res = try? JSONDecoder().decode(LFMTrackInfoResponse.self, from: data) {
                    fetchedDetails.description = res.track.wiki?.summary?.stripHTML()
                    if let similar = res.track.similar?.track {
                        fetchedDetails.similarTracks = similar.map {
                            ScrobbledTrack(name: $0.name, artist: $0.artist.name, album: "", timestamp: nil, imageURL: URL(string: $0.image?.last?.url ?? ""))
                        }
                    }
                } else if urlType == "album", let res = try? JSONDecoder().decode(LFMAlbumInfoResponse.self, from: data) {
                    fetchedDetails.description = res.album.wiki?.summary?.stripHTML()
                }
            }
            DispatchQueue.main.async { self.entityDetails[id] = fetchedDetails }
        }
    }
}

// MARK: - Reusable Views
struct CachedAsyncImage: View {
    let url: URL?; let fallbackIcon: String; var shape: AnyShape = AnyShape(Rectangle())
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill).clipShape(shape)
            } else if phase.error != nil {
                ZStack { Color.lastFmGray; Image(systemName: fallbackIcon).font(.largeTitle).foregroundColor(.gray) }.clipShape(shape)
            } else {
                ZStack { Color.lastFmGray; ProgressView() }.clipShape(shape)
            }
        }
    }
}

struct DescriptionBoxView: View {
    let text: String?
    var body: some View {
        if let desc = text, !desc.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("About").font(.title2).fontWeight(.bold).padding(.top)
                Text(desc).font(.body).lineSpacing(4).foregroundColor(.primary)
            }.padding(.vertical, 10)
        }
    }
}


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

// MARK: - Detail Views (Hero Headers)
struct HeroHeaderView: View {
    let title: String; let subtitle: String; let statValue: String; let statLabel: String; let imageURL: URL?; let fallbackIcon: String; let isCircular: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.lastFmDark.edgesIgnoringSafeArea(.top)
            HStack(alignment: .bottom, spacing: 20) {
                CachedAsyncImage(url: imageURL, fallbackIcon: fallbackIcon, shape: isCircular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 4)))
                    .frame(width: 180, height: 180).shadow(radius: 10).padding(.leading, 30).padding(.bottom, -30)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.system(size: 40, weight: .black)).foregroundColor(.white)
                    Text(subtitle).font(.title2).foregroundColor(.gray)
                    HStack {
                        VStack(alignment: .leading) {
                            Text(statValue).font(.title3).fontWeight(.bold).foregroundColor(.white)
                            Text(statLabel).font(.caption).foregroundColor(.gray).textCase(.uppercase)
                        }
                    }.padding(.top, 10)
                }.padding(.bottom, 20)
                Spacer()
            }
        }.frame(height: 250).padding(.bottom, 40)
    }
}

struct TrackDetailView: View {
    let track: ScrobbledTrack; @ObservedObject var manager: ScrobblerManager
    let id: String
    
    init(track: ScrobbledTrack, manager: ScrobblerManager) {
        self.track = track; self.manager = manager
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

struct ArtistDetailView: View {
    let artist: TopArtist; @ObservedObject var manager: ScrobblerManager
    let id: String
    
    init(artist: TopArtist, manager: ScrobblerManager) {
        self.artist = artist; self.manager = manager
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

struct AlbumDetailView: View {
    let album: TopAlbum; @ObservedObject var manager: ScrobblerManager
    let id: String
    
    init(album: TopAlbum, manager: ScrobblerManager) {
        self.album = album; self.manager = manager
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

// MARK: - Library Views (Last.fm Style)

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

struct EntityGridView<Item: Identifiable & Hashable>: View {
    let items: [Item]; let title: String; let fallbackIcon: String; let isCircular: Bool
    let getName: (Item) -> String; let getSubtitle: (Item) -> String?; let getCount: (Item) -> Int; let getURL: (Item) -> URL?
    
    let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(title).font(.largeTitle).fontWeight(.black).padding(.horizontal).padding(.top)
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            VStack(alignment: .center) {
                                CachedAsyncImage(url: getURL(item), fallbackIcon: fallbackIcon, shape: isCircular ? AnyShape(Circle()) : AnyShape(Rectangle()))
                                    .frame(width: 150, height: 150).shadow(radius: isCircular ? 0 : 3)
                                Text(getName(item)).font(.headline).lineLimit(1).multilineTextAlignment(.center).foregroundColor(.primary)
                                if let sub = getSubtitle(item) {
                                    Text(sub).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                                }
                                Text("\(getCount(item)) scrobbles").font(.caption).foregroundColor(.gray)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }
        }
    }
}

struct TopArtistsView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        EntityGridView(items: manager.topArtists, title: "Top Artists", fallbackIcon: "music.mic", isCircular: true,
                       getName: { $0.name }, getSubtitle: { _ in nil }, getCount: { $0.playcount }, getURL: { $0.imageURL })
        .navigationDestination(for: TopArtist.self) { artist in ArtistDetailView(artist: artist, manager: manager) }
    }
}

struct TopAlbumsView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        EntityGridView(items: manager.topAlbums, title: "Top Albums", fallbackIcon: "square.stack.fill", isCircular: false,
                       getName: { $0.name }, getSubtitle: { $0.artist }, getCount: { $0.playcount }, getURL: { $0.imageURL })
        .navigationDestination(for: TopAlbum.self) { album in AlbumDetailView(album: album, manager: manager) }
    }
}

// MARK: - Auth & Dashboard Views
struct AuthView: View {
    @ObservedObject var manager: ScrobblerManager
    var body: some View {
        VStack(spacing: 30) {
            Text("last.fm").font(.system(size: 60, weight: .black)).foregroundColor(.lastFmRed)
            
            if !manager.isAwaitingWebApproval {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Credentials").font(.headline).foregroundColor(.secondary)
                        TextField("API Key", text: $manager.apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .controlSize(.large)
                        SecureField("Shared Secret", text: $manager.apiSecret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .controlSize(.large)
                    }
                    .padding()
                    .frame(width: 400)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    Button("Connect to Last.fm") { manager.beginWebAuth() }
                        .buttonStyle(.borderedProminent)
                        .tint(.lastFmRed)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .disabled(manager.apiKey.isEmpty || manager.apiSecret.isEmpty)
                    
                    Link("Get an API account at last.fm", destination: URL(string: "https://www.last.fm/api/account/create")!)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5).padding()
                    Text("Check your web browser").font(.headline)
                    Button("I've Authorized The App") { manager.completeWebAuth() }
                    .buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                    Button("Cancel") { manager.isAwaitingWebApproval = false }.buttonStyle(.plain).foregroundColor(.secondary)
                }.padding().frame(width: 400)
            }
        }.padding(40)
    }
}

struct MainDashboardView: View {
    @ObservedObject var manager: ScrobblerManager
    @State private var selection: SidebarItem? = .profile
    enum SidebarItem: Hashable { case profile, recent, topArtists, topAlbums }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Me") {
                    NavigationLink(value: SidebarItem.profile) { Label("Profile", systemImage: "person.fill") }
                }
                Section("Library") {
                    NavigationLink(value: SidebarItem.recent) { Label("Recent Tracks", systemImage: "music.note.list") }
                    NavigationLink(value: SidebarItem.topArtists) { Label("Top Artists", systemImage: "music.mic") }
                    NavigationLink(value: SidebarItem.topAlbums) { Label("Top Albums", systemImage: "square.stack.fill") }
                }
            }
            .navigationTitle("Last.fm")
            .listStyle(SidebarListStyle())
            
            VStack {
                Spacer()
                if manager.isRunning {
                    HStack {
                        Image(systemName: "waveform").foregroundColor(.lastFmRed)
                        Text(manager.localNowPlaying != nil ? "Scrobbling" : "Waiting for Music...").font(.caption).fontWeight(.bold)
                    }.padding(.bottom, 8)
                } else {
                    Button("Start Scrobbler") { manager.start() }.buttonStyle(.bordered).padding(.bottom, 8)
                }
                Button(action: { manager.logout() }) {
                    HStack { Image(systemName: "rectangle.portrait.and.arrow.right"); Text("Logout") }.foregroundColor(.secondary)
                }.buttonStyle(.plain).padding(.bottom)
            }
        } detail: {
            NavigationStack {
                switch selection {
                case .profile: ProfileView(manager: manager)
                case .recent: RecentTracksView(manager: manager)
                case .topArtists: TopArtistsView(manager: manager)
                case .topAlbums: TopAlbumsView(manager: manager)
                case .none: Text("Select an item")
                }
            }
            .navigationDestination(for: UserInfo.self) { user in
                UserDetailView(username: user.username, manager: manager)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = ScrobblerManager()
    var body: some View {
        Group {
            if manager.isAuthenticated { MainDashboardView(manager: manager) }
            else { AuthView(manager: manager) }
        }.frame(minWidth: 900, minHeight: 650)
    }
}

@main
struct MusicLastFMApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }.windowStyle(.hiddenTitleBar)
    }
}
