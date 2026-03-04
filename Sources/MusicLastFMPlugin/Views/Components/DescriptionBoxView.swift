import SwiftUI

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
