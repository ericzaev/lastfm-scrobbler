import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var manager: ScrobblerManager
    var body: some View {
        Group {
            if manager.isAuthenticated { MainDashboardView(manager: manager) }
            else { AuthView(manager: manager) }
        }.frame(minWidth: 900, minHeight: 650)
    }
}
