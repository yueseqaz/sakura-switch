import CoreGraphics

public enum WindowPreviewGeometry {
    /// Fit the source window inside a capture area without changing its aspect
    /// ratio. Unknown window frames use the requested bounds as a placeholder.
    public static func fittedSize(source: CGSize, bounds: CGSize) -> CGSize {
        guard source.width.isFinite, source.height.isFinite,
              source.width > 1, source.height > 1 else { return bounds }
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }
}
