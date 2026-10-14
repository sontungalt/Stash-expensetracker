import CoreGraphics
import Foundation
import SwiftUI
import UIKit

nonisolated struct StashManifest: Decodable, Sendable {
    let atlases: [String: String]
    let poses: [Pose]
    let animations: [String: MotionTrack]

    struct Pose: Decodable, Sendable {
        let key: String
        let name: String
        let duration: Double
        let crop: [Double]
        let shadow: [Double]?
        let bodyMotion: Motion
        let shadowMotion: Motion
        let parts: [Part]
    }
    struct Part: Decodable, Sendable {
        let name: String
        let atlas: String
        let crop: [Double]
        let anchor: [Double]
        let motion: Motion
    }
    struct Motion: Decodable, Sendable {
        let animation: String?
        let duration: Double
        let delay: Double
        let linear: Bool
    }
    struct MotionTrack: Decodable, Sendable {
        struct TransformFrame: Decodable, Sendable { let t: Double; let values: [Double] }
        struct OpacityFrame: Decodable, Sendable { let t: Double; let value: Double }
        let order: [String]
        let transforms: [TransformFrame]
        let opacities: [OpacityFrame]
    }

    static func load(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "stash-animation", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func sample(_ motion: Motion, time: TimeInterval?) -> (transform: CGAffineTransform, opacity: Double) {
        guard let time, let name = motion.animation, let track = animations[name] else { return (.identity, 1) }
        let cycle = ((time - motion.delay) / motion.duration).truncatingRemainder(dividingBy: 1)
        let phase = cycle < 0 ? cycle + 1 : cycle
        let values = interpolate(track.transforms.map { ($0.t, $0.values) }, at: phase, linear: motion.linear,
                                 fallback: [0, 0, 1, 1, 0, 0, 0])
        let opacity = interpolate(track.opacities.map { ($0.t, [$0.value]) }, at: phase, linear: motion.linear,
                                  fallback: [1])[0]
        var transform = CGAffineTransform.identity
        for operation in track.order {
            switch operation {
            case "translate": transform = transform.translatedBy(x: values[0], y: values[1])
            case "scale": transform = transform.scaledBy(x: values[2], y: values[3])
            case "rotate": transform = transform.rotated(by: values[4] * .pi / 180)
            case "skewX": transform = CGAffineTransform(a: 1, b: 0, c: tan(values[5] * .pi / 180), d: 1, tx: 0, ty: 0).concatenating(transform)
            case "skewY": transform = CGAffineTransform(a: 1, b: tan(values[6] * .pi / 180), c: 0, d: 1, tx: 0, ty: 0).concatenating(transform)
            default: break
            }
        }
        return (transform, opacity)
    }

    private func interpolate(_ frames: [(Double, [Double])], at time: Double, linear: Bool, fallback: [Double]) -> [Double] {
        guard let first = frames.first, let last = frames.last else { return fallback }
        if time <= first.0 { return first.1 }
        if time >= last.0 { return last.1 }
        guard let end = frames.firstIndex(where: { $0.0 > time }), end > 0 else { return fallback }
        let a = frames[end - 1], b = frames[end]
        let fraction = (time - a.0) / (b.0 - a.0)
        let t = linear ? fraction : Self.easeInOut(fraction)
        return zip(a.1, b.1).map { $0 + ($1 - $0) * t }
    }

    // CSS ease-in-out: cubic-bezier(0.42, 0, 0.58, 1).
    private static func easeInOut(_ x: Double) -> Double {
        var low = 0.0, high = 1.0
        for _ in 0..<12 {
            let t = (low + high) / 2, inverse = 1 - t
            let value = 3 * inverse * inverse * t * 0.42 + 3 * inverse * t * t * 0.58 + t * t * t
            if value < x { low = t } else { high = t }
        }
        let t = (low + high) / 2
        return 3 * (1 - t) * t * t + t * t * t
    }
}

/// Atlas crops are cached once. The widget uses separate 30-point portraits.
@MainActor final class StashArtwork {
    static let shared = try? StashArtwork()
    let manifest: StashManifest
    private var crops: [String: Image] = [:]

    private init() throws {
        manifest = try StashManifest.load()
        var atlases: [String: CGImage] = [:]
        for (key, name) in manifest.atlases {
            if let path = Bundle.main.path(forResource: name, ofType: "png"), let cg = UIImage(contentsOfFile: path)?.cgImage {
                atlases[key] = cg
            }
        }
        guard atlases.count == manifest.atlases.count else { throw CocoaError(.fileNoSuchFile) }
        for pose in manifest.poses {
            add(atlas: "body", crop: pose.crop, sources: atlases)
            if let shadow = pose.shadow { add(atlas: "shadow", crop: shadow, sources: atlases) }
            for part in pose.parts { add(atlas: part.atlas, crop: part.crop, sources: atlases) }
        }
    }

    func image(atlas: String, crop: [Double]) -> Image? { crops[key(atlas, crop)] }
    private func key(_ atlas: String, _ crop: [Double]) -> String { atlas + crop.map { String(Int($0)) }.joined(separator: ",") }
    private func add(atlas: String, crop: [Double], sources: [String: CGImage]) {
        let rect = CGRect(x: crop[0], y: crop[1], width: crop[2], height: crop[3])
        if let image = sources[atlas]?.cropping(to: rect) {
            crops[key(atlas, crop)] = Image(decorative: image, scale: 1).interpolation(.none).antialiased(false)
        }
    }
}
