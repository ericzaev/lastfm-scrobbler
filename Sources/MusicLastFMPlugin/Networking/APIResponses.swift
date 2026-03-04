import Foundation

struct LFMImage: Decodable {
    let size: String
    let url: String
    enum CodingKeys: String, CodingKey { case size; case url = "#text" }
}

struct LFMWiki: Decodable {
    let summary: String?
    let content: String?
}

struct LFMUserResponse: Decodable {
    struct User: Decodable {
        let name: String
        let realname: String?
        let playcount: String
        let image: [LFMImage]?
        let registered: Registered
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

struct TokenResponse: Decodable {
    let token: String?
}

struct SessionResponse: Decodable {
    struct Session: Decodable { let name: String; let key: String }
    let session: Session?
    let message: String?
}
