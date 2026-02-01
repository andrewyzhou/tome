import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 56))
                .foregroundColor(.primary)

            Text("Tome")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Version \(version)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 4) {
                Text("Andrew Zhou")
                    .font(.body)
                Link("andrewzhou.org", destination: URL(string: "https://andrewzhou.org")!)
                    .font(.body)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 340, height: 300)
    }
}
