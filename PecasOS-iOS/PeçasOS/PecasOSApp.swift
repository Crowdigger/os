import SwiftUI

@main
struct PecasOSApp: App {
    @StateObject private var store = PieceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
