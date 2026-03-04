import SwiftUI

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
