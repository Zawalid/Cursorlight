import CoreGraphics

public enum SkinGeometry {
    /// Frame for a skin layer inside an overlay window, in the window's layer coordinates (points, bottom-left
    /// origin), such that the image's hotspot lands on `pointer`.
    ///
    /// - Parameters:
    ///   - pointer: Pointer position in global screen coordinates (`NSEvent.mouseLocation` convention).
    ///   - windowOrigin: The overlay window's frame origin in the same coordinates.
    ///   - imagePixelSize: Size of the rendered image in pixels.
    ///   - hotspotPixels: Hotspot in image pixels, measured from the image's top-left corner.
    ///   - backingScale: The window's display scale. Each image pixel maps to one device pixel, and the frame
    ///     is snapped to the device pixel grid so the art stays crisp; the hotspot then sits within half a device
    ///     pixel of the pointer, and exactly on it whenever the pointer is on the grid.
    public static func layerFrame(
        pointer: CGPoint,
        windowOrigin: CGPoint,
        imagePixelSize: CGSize,
        hotspotPixels: CGPoint,
        backingScale: CGFloat
    ) -> CGRect {
        let scale = max(backingScale, 0.01)
        let localX = (pointer.x - windowOrigin.x) * scale
        let localY = (pointer.y - windowOrigin.y) * scale
        let left = (localX - hotspotPixels.x).rounded()
        let top = (localY + hotspotPixels.y).rounded()
        return CGRect(
            x: left / scale,
            y: (top - imagePixelSize.height) / scale,
            width: imagePixelSize.width / scale,
            height: imagePixelSize.height / scale
        )
    }
}
