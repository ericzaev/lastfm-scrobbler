import Foundation

struct Track: Equatable {
    var name: String
    var artist: String
    var album: String
    var duration: Double? = nil
}

struct UserProfile {
    var username: String
    var realName: String
    var playcount: Int
    var registered: Date
    var avatarURL: URL?
}

struct ScrobbledTrack: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let artist: String
    let album: String
    let timestamp: Date?
    let imageURL: URL?
}

struct TopArtist: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let playcount: Int
    let imageURL: URL?
}

struct TopAlbum: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let artist: String
    let playcount: Int
    let imageURL: URL?
}

struct UserInfo: Identifiable, Hashable {
    let id = UUID()
    let username: String
}

struct EntityDetails {
    var description: String?
    var similarArtists: [TopArtist] = []
    var similarTracks: [ScrobbledTrack] = []
}
