import SwiftUI

struct StashAnimatedView: View {
    let pose: StashPose
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date.now
    @State private var visible = true

    var body: some View {
        Group {
            if let artwork = StashArtwork.shared, let drawing = artwork.manifest.poses.first(where: { $0.key == pose.rawValue }) {
                TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || scenePhase != .active || !visible)) { timeline in
                    let time: TimeInterval? = reduceMotion ? nil : timeline.date.timeIntervalSince(startedAt)
                    Canvas { context, size in
                        let scale = min(size.width / (drawing.crop[2] + 36), size.height / (drawing.crop[3] + 36))
                        let origin = CGPoint(x: (size.width - drawing.crop[2] * scale) / 2,
                                             y: (size.height - drawing.crop[3] * scale) / 2)
                        var stage = context
                        stage.translateBy(x: origin.x, y: origin.y)
                        stage.scaleBy(x: scale, y: scale)
                        if let shadow = drawing.shadow {
                            draw(atlas: "shadow", crop: shadow, origin: drawing.crop, anchor: [0.5, 0.5], motion: drawing.shadowMotion,
                                 time: time, artwork: artwork, context: stage)
                        }
                        let body = artwork.manifest.sample(drawing.bodyMotion, time: time)
                        stage.opacity *= body.opacity
                        stage.translateBy(x: drawing.crop[2] / 2, y: drawing.crop[3])
                        stage.concatenate(body.transform)
                        stage.translateBy(x: -drawing.crop[2] / 2, y: -drawing.crop[3])
                        if let image = artwork.image(atlas: "body", crop: drawing.crop) {
                            stage.draw(image, in: CGRect(x: 0, y: 0, width: drawing.crop[2], height: drawing.crop[3]))
                        }
                        for part in drawing.parts {
                            draw(atlas: part.atlas, crop: part.crop, origin: drawing.crop, anchor: part.anchor, motion: part.motion,
                                 time: time, artwork: artwork, context: stage)
                        }
                    }
                }
            } else {
                StashPortrait(pose: pose)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stash, \(pose.title)")
        .onChange(of: pose) { startedAt = .now }
        .onAppear { visible = true; startedAt = .now }
        .onDisappear { visible = false }
        .onScrollVisibilityChange(threshold: 0.1) { visible = $0 }
    }

    private func draw(atlas: String, crop: [Double], origin: [Double], anchor: [Double], motion: StashManifest.Motion,
                      time: TimeInterval?, artwork: StashArtwork, context: GraphicsContext) {
        guard let image = artwork.image(atlas: atlas, crop: crop) else { return }
        let state = artwork.manifest.sample(motion, time: time)
        var layer = context
        layer.opacity *= state.opacity
        layer.translateBy(x: crop[0] - origin[0] + crop[2] * anchor[0], y: crop[1] - origin[1] + crop[3] * anchor[1])
        layer.concatenate(state.transform)
        layer.translateBy(x: -crop[2] * anchor[0], y: -crop[3] * anchor[1])
        layer.draw(image, in: CGRect(x: 0, y: 0, width: crop[2], height: crop[3]))
    }
}
