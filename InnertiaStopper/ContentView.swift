import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Global Scroll Control")
                .font(.largeTitle)
                .padding()
            Text("Scroll suppression is active. Move the mouse or use the wheel to test.")
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

