// Compile/run on macOS. Compose the original sprite layers into tiny WidgetKit assets.
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manifestURL = root.appending(path: "ios/ExpenseTracker/Resources/Stash/stash-animation.json")
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
let atlasNames = manifest["atlases"] as! [String: String]
let atlasDirectory = root.appending(path: "docs/mascot/assets")
var atlases: [String: CGImage] = [:]
for (name, file) in atlasNames {
    let source = CGImageSourceCreateWithURL(atlasDirectory.appending(path: file + ".png") as CFURL, nil)!
    atlases[name] = CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
let catalog = root.appending(path: "ios/StashShared/Portraits.xcassets")
try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
let info: [String: Any] = ["info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]).write(to: catalog.appending(path: "Contents.json"))
for pose in manifest["poses"] as! [[String: Any]] {
    let key = pose["key"] as! String
    let base = pose["crop"] as! [Double]
    let directory = catalog.appending(path: "Stash-\(key).imageset")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var entries: [[String: String]] = []
    for density in 1...3 {
        let dimension = 30 * density
        let context = CGContext(data: nil, width: dimension, height: dimension, bitsPerComponent: 8,
                                bytesPerRow: dimension * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        // Adopt the reference's top-left coordinate system.
        context.translateBy(x: 0, y: CGFloat(dimension))
        context.scaleBy(x: 1, y: -1)
        let scale = min(Double(dimension) / (base[2] + 16), Double(dimension) / (base[3] + 16))
        let x = (Double(dimension) - base[2] * scale) / 2
        let y = (Double(dimension) - base[3] * scale) / 2
        func draw(_ atlas: String, _ rect: [Double]) {
            let cg = atlases[atlas]!.cropping(to: CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3]))!
            let destination = CGRect(x: x + (rect[0] - base[0]) * scale, y: y + (rect[1] - base[1]) * scale,
                                     width: rect[2] * scale, height: rect[3] * scale)
            context.saveGState()
            context.translateBy(x: destination.minX, y: destination.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(cg, in: CGRect(origin: .zero, size: destination.size))
            context.restoreGState()
        }
        if let shadow = pose["shadow"] as? [Double] { draw("shadow", shadow) }
        draw("body", base)
        for part in pose["parts"] as! [[String: Any]] { draw(part["atlas"] as! String, part["crop"] as! [Double]) }
        let filename = "stash@\(density)x.png"
        let destination = CGImageDestinationCreateWithURL(directory.appending(path: filename) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }
        entries.append(["idiom": "universal", "scale": "\(density)x", "filename": filename])
    }
    let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appending(path: "Contents.json"))
}
print("Composed 18 Stash portraits at 1x, 2x and 3x.")
