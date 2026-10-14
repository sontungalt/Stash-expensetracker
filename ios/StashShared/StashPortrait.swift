import SwiftUI

struct StashPortrait: View {
    let pose: StashPose
    var body: some View {
        Image("Stash-\(pose.rawValue)")
            .resizable().interpolation(.none).antialiased(false)
            .scaledToFit()
            .accessibilityLabel("Stash, \(pose.title)")
    }
}
