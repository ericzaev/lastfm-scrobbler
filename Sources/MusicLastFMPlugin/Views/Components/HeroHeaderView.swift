import SwiftUI

struct HeroHeaderView: View {
    let title: String
    let subtitle: String
    let statValue: String
    let statLabel: String
    let imageURL: URL?
    let fallbackIcon: String
    let isCircular: Bool
    
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
