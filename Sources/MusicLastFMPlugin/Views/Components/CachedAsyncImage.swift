import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    let fallbackIcon: String
    var shape: AnyShape = AnyShape(Rectangle())
    
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
