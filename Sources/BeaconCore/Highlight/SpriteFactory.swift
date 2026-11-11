import CoreGraphics
import Foundation

/// Builds radial-gradient bitmaps once, so glows are composited from cached images instead of being rasterized
/// (or blurred) every frame. Alpha is dithered by half a level to keep large soft gradients from banding in
/// compressed screen-share video.
@MainActor
enum SpriteFactory {
    private struct Key: Hashable {
        let name: String
        let color: RGBA
        let scale: CGFloat
    }

    private static var cache: [Key: CGImage] = [:]

    /// A square image of side `2 * extent` points whose alpha at distance d (points) from the center is `alpha(d)`.
    static func radial(
        name: String, extent: CGFloat, scale: CGFloat, color: RGBA, alpha: (CGFloat) -> CGFloat
    ) -> CGImage? {
        let key = Key(name: name, color: color, scale: scale)
        if let cached = cache[key] { return cached }
        let side = max(Int((2 * extent * scale).rounded(.up)), 2)
        let center = CGFloat(side) / 2
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let dx = (CGFloat(x) + 0.5 - center) / scale
                let dy = (CGFloat(y) + 0.5 - center) / scale
                let a = min(max(alpha(hypot(dx, dy)), 0), 1)
                guard a > 0 else { continue }
                let dithered = min(max(Double(a) * 255 + dither(x, y), 0), 255)
                let alpha8 = dithered.rounded()
                let index = (y * side + x) * 4
                // Premultiplied.
                pixels[index] = UInt8((color.red * alpha8).rounded())
                pixels[index + 1] = UInt8((color.green * alpha8).rounded())
                pixels[index + 2] = UInt8((color.blue * alpha8).rounded())
                pixels[index + 3] = UInt8(alpha8)
            }
        }
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let image = CGImage(
                width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
            )
        else { return nil }
        cache[key] = image
        return image
    }

    /// A disk of radius `radius` blurred by a gaussian of `blur` points (sigma = blur / 2), peaking at `peak`.
    static func blurredDisk(
        name: String, radius: CGFloat, blur: CGFloat, peak: CGFloat, scale: CGFloat, color: RGBA
    ) -> (image: CGImage?, extent: CGFloat) {
        let sigma = max(blur / 2, 0.5)
        let extent = radius + 3 * sigma
        let image = radial(name: name, extent: extent, scale: scale, color: color) { d in
            peak * CGFloat(0.5 * erfc(Double(d - radius) / (Double(sigma) * 2.squareRoot())))
        }
        return (image, extent)
    }

    /// Ordered noise in -0.5...0.5 of one 8-bit level.
    private static func dither(_ x: Int, _ y: Int) -> Double {
        let v = sin(Double(x) * 12.9898 + Double(y) * 78.233) * 43758.5453
        return (v - v.rounded(.down)) - 0.5
    }
}
