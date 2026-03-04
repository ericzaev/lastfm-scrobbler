import SwiftUI
import Combine

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
    
    private var service: LastFMService {
        LastFMService(apiKey: apiKey, apiSecret: apiSecret)
    }
    
    init() {
        if isAuthenticated {
            fetchLiveData()
            start()
        }
    }
    
    var hasValidCredentials: Bool {
        return !apiKey.isEmpty && !apiSecret.isEmpty
    }
    
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
    
    func stop() {
        isRunning = false
        scrobbleTask?.cancel()
        scrobbleTask = nil
        localNowPlaying = nil
    }
    
    private func checkTrack() async {
        if let track = MusicMonitor.getCurrentTrack() {
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
        } else {
            self.localNowPlaying = nil
        }
    }
    
    private func scrobbleLocal(track: Track) {
        guard isAuthenticated else { return }
        recentTracks.removeAll { $0.timestamp == nil }
        let newScrobble = ScrobbledTrack(name: track.name, artist: track.artist, album: track.album, timestamp: nil, imageURL: nil)
        recentTracks.insert(newScrobble, at: 0)
    }
    
    private func sendNowPlayingToAPI(track: Track) {
        guard isAuthenticated, !sessionKey.isEmpty else { return }
        let params: [String: String] = [
            "artist": track.artist,
            "track": track.name,
            "album": track.album,
            "sk": sessionKey
        ]
        
        Task {
            let _ = try? await service.fetch(EmptyResponse.self, method: "track.updateNowPlaying", params: params, isPost: true)
        }
    }
    
    struct EmptyResponse: Decodable {}
    
    private func sendScrobbleToAPI(track: Track, timestamp: Date) {
        guard isAuthenticated, !sessionKey.isEmpty else { return }
        let timeString = String(Int(timestamp.timeIntervalSince1970))
        let params: [String: String] = [
            "artist[0]": track.artist,
            "track[0]": track.name,
            "album[0]": track.album,
            "timestamp[0]": timeString,
            "sk": sessionKey
        ]
        
        Task {
            let _ = try? await service.fetch(EmptyResponse.self, method: "track.scrobble", params: params, isPost: true)
            fetchLiveData()
        }
    }
    
    func beginWebAuth() {
        guard hasValidCredentials else { return }
        Task {
            do {
                let params = ["method": "auth.getToken", "api_key": apiKey]
                let sig = service.generateSignature(params: params)
                let urlString = "https://ws.audioscrobbler.com/2.0/?method=auth.getToken&api_key=\(apiKey)&api_sig=\(sig)&format=json"
                guard let url = URL(string: urlString) else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                if let token = response.token {
                    self.currentAuthToken = token
                    self.isAwaitingWebApproval = true
                    if let authURL = URL(string: "https://www.last.fm/api/auth/?api_key=\(self.apiKey)&token=\(token)") {
                        NSWorkspace.shared.open(authURL)
                    }
                }
            } catch { print("Auth error: \(error)") }
        }
    }
    
    func completeWebAuth() {
        guard hasValidCredentials, !currentAuthToken.isEmpty else { return }
        Task {
            do {
                let params = ["api_key": apiKey, "method": "auth.getSession", "token": currentAuthToken]
                let sig = service.generateSignature(params: params)
                let urlString = "https://ws.audioscrobbler.com/2.0/?method=auth.getSession&api_key=\(apiKey)&token=\(currentAuthToken)&api_sig=\(sig)&format=json"
                guard let url = URL(string: urlString) else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(SessionResponse.self, from: data)
                if let session = response.session {
                    self.username = session.name
                    self.sessionKey = session.key
                    self.isAuthenticated = true
                    self.isAwaitingWebApproval = false
                    self.fetchLiveData()
                    self.start()
                } else {
                    self.isAwaitingWebApproval = false
                }
            } catch { self.isAwaitingWebApproval = false }
        }
    }
    
    func logout() {
        stop()
        isAuthenticated = false
        sessionKey = ""
        currentAuthToken = ""
        isAwaitingWebApproval = false
        profile = nil
        recentTracks = []
        topArtists = []
        topAlbums = []
        localNowPlaying = nil
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
            self.isFetchingData = false
        }
    }
    
    private func fetchProfile() async {
        do {
            let res = try await service.fetch(LFMUserResponse.self, method: "user.getinfo", params: ["user": username])
            let u = res.user
            let avatarUrlStr = u.image?.first(where: { $0.size == "extralarge" })?.url ?? u.image?.last?.url
            self.profile = UserProfile(
                username: u.name,
                realName: u.realname ?? u.name,
                playcount: Int(u.playcount) ?? 0,
                registered: Date(timeIntervalSince1970: TimeInterval(u.registered.unixtime) ?? 0),
                avatarURL: avatarUrlStr != nil && !avatarUrlStr!.isEmpty ? URL(string: avatarUrlStr!) : nil
            )
        } catch { print("Fetch profile error: \(error)") }
    }
    
    func fetchOtherProfile(username: String) {
        Task {
            do {
                let res = try await service.fetch(LFMUserResponse.self, method: "user.getinfo", params: ["user": username])
                let u = res.user
                let avatarUrlStr = u.image?.first(where: { $0.size == "extralarge" })?.url ?? u.image?.last?.url
                let p = UserProfile(
                    username: u.name,
                    realName: u.realname ?? u.name,
                    playcount: Int(u.playcount) ?? 0,
                    registered: Date(timeIntervalSince1970: TimeInterval(u.registered.unixtime) ?? 0),
                    avatarURL: avatarUrlStr != nil && !avatarUrlStr!.isEmpty ? URL(string: avatarUrlStr!) : nil
                )
                self.otherProfiles[username] = p
            } catch { print("Fetch other profile error: \(error)") }
        }
    }
    
    private func fetchRecentTracks() async {
        do {
            let res = try await service.fetch(LFMRecentTracksResponse.self, method: "user.getrecenttracks", params: ["user": username, "limit": "50"])
            self.recentTracks = res.recenttracks.track.map { t in
                var d: Date? = nil
                if t.attr?.nowplaying != "true" {
                    if let uts = t.date?.uts, let time = TimeInterval(uts) { d = Date(timeIntervalSince1970: time) }
                }
                let imgUrlStr = t.image?.first(where: { $0.size == "extralarge" })?.url ?? t.image?.last?.url
                return ScrobbledTrack(name: t.name, artist: t.artist.name, album: t.album.title, timestamp: d, imageURL: imgUrlStr != nil && !imgUrlStr!.isEmpty ? URL(string: imgUrlStr!) : nil)
            }
        } catch { print("Fetch recent tracks error: \(error)") }
    }
    
    private func fetchTopArtists() async {
        do {
            let res = try await service.fetch(LFMTopArtistsResponse.self, method: "user.gettopartists", params: ["user": username, "limit": "50"])
            self.topArtists = res.topartists.artist.map { a in
                let imgUrlStr = a.image?.first(where: { $0.size == "extralarge" })?.url ?? a.image?.last?.url
                return TopArtist(name: a.name, playcount: Int(a.playcount) ?? 0, imageURL: imgUrlStr != nil && !imgUrlStr!.isEmpty ? URL(string: imgUrlStr!) : nil)
            }
        } catch { print("Fetch top artists error: \(error)") }
    }
    
    private func fetchTopAlbums() async {
        do {
            let res = try await service.fetch(LFMTopAlbumsResponse.self, method: "user.gettopalbums", params: ["user": username, "limit": "50"])
            self.topAlbums = res.topalbums.album.map { a in
                let imgUrlStr = a.image?.first(where: { $0.size == "extralarge" })?.url ?? a.image?.last?.url
                return TopAlbum(name: a.name, artist: a.artist.name, playcount: Int(a.playcount) ?? 0, imageURL: imgUrlStr != nil && !imgUrlStr!.isEmpty ? URL(string: imgUrlStr!) : nil)
            }
        } catch { print("Fetch top albums error: \(error)") }
    }
    
    func fetchInfo(for urlType: String, artist: String, track: String? = nil, album: String? = nil, id: String) {
        Task {
            var fetchedDetails = EntityDetails()
            do {
                if urlType == "artist" {
                    let res = try await service.fetch(LFMArtistInfoResponse.self, method: "artist.getinfo", params: ["artist": artist])
                    fetchedDetails.description = res.artist.bio?.summary?.stripHTML()
                    if let similar = res.artist.similar?.artist {
                        fetchedDetails.similarArtists = similar.map {
                            TopArtist(name: $0.name, playcount: 0, imageURL: URL(string: $0.image?.last?.url ?? ""))
                        }
                    }
                } else if urlType == "track" {
                    let res = try await service.fetch(LFMTrackInfoResponse.self, method: "track.getinfo", params: ["artist": artist, "track": track ?? ""])
                    fetchedDetails.description = res.track.wiki?.summary?.stripHTML()
                    if let similar = res.track.similar?.track {
                        fetchedDetails.similarTracks = similar.map {
                            ScrobbledTrack(name: $0.name, artist: $0.artist.name, album: "", timestamp: nil, imageURL: URL(string: $0.image?.last?.url ?? ""))
                        }
                    }
                } else if urlType == "album" {
                    let res = try await service.fetch(LFMAlbumInfoResponse.self, method: "album.getinfo", params: ["artist": artist, "album": album ?? ""])
                    fetchedDetails.description = res.album.wiki?.summary?.stripHTML()
                }
                self.entityDetails[id] = fetchedDetails
            } catch { print("Fetch info error: \(error)") }
        }
    }
}
