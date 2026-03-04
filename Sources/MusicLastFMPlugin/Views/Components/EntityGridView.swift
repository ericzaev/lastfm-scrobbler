import SwiftUI

struct EntityGridView<Item: Identifiable & Hashable>: View {
    let items: [Item]
    let title: String
    let fallbackIcon: String
    let isCircular: Bool
    let getName: (Item) -> String
    let getSubtitle: (Item) -> String?
    let getCount: (Item) -> Int
    let getURL: (Item) -> URL?
    
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
