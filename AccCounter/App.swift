import SwiftUI

@main
struct AccCounterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea(.all)
                .preferredColorScheme(.light)
                .statusBarHidden(false)
        }
    }
}
