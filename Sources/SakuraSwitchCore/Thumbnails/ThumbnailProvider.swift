import AppKit
import CoreGraphics
import ScreenCaptureKit
import os

/// Window thumbnail provider.
/// - macOS 14+: ScreenCaptureKit `SCScreenshotManager` per-window capture.
/// - macOS 13: `CGWindowListCreateImage` fallback.
/// - TTL cache (5 s); one in-flight capture per window; icon placeholder
///   when Screen Recording is missing.
public actor ThumbnailProvider {

    public static let shared = ThumbnailProvider()

    public static let ttl: TimeInterval = 5

    private struct Entry {
        let image: NSImage
        let at: Date
    }

    private var cache: [CGWindowID: Entry] = [:]
    private var inFlight: Set<CGWindowID> = []

    /// Cached shareable content (SC enumeration is expensive).
    private var scContent: (windows: [SCWindow], at: Date)?

    public init() {}

    // MARK: - Public

    /// Latest thumbnail for a window, or nil (caller shows the app icon).
    public func thumbnail(for window: WindowModel, size: CGSize) async -> NSImage? {
        guard ScreenCapturePermission.isGranted else { return nil }
        if let entry = cache[window.windowID],
           Date().timeIntervalSince(entry.at) < Self.ttl {
            return entry.image
        }
        // Coalesce duplicate requests for the same window.
        guard !inFlight.contains(window.windowID) else {
            return cache[window.windowID]?.image
        }
        inFlight.insert(window.windowID)
        defer { inFlight.remove(window.windowID) }

        let image = await capture(windowID: window.windowID, size: size)
        if let image {
            cache[window.windowID] = Entry(image: image, at: Date())
        } else {
            Log.thumbnails.debug("Capture failed for a window")
        }
        return image
    }

    public func invalidateAll() {
        cache.removeAll()
        scContent = nil
    }

    public func invalidate(windowID: CGWindowID) {
        cache.removeValue(forKey: windowID)
    }

    // MARK: - Capture

    private func capture(windowID: CGWindowID, size: CGSize) async -> NSImage? {
        if #available(macOS 14.0, *) {
            return await captureWithScreenCaptureKit(windowID: windowID, size: size)
        } else {
            return Self.captureWithLegacyCG(windowID: windowID, size: size)
        }
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(windowID: CGWindowID, size: CGSize) async -> NSImage? {
        // Refresh the SC window list at most every 2 seconds.
        if let scContent, Date().timeIntervalSince(scContent.at) < 2 {
            // still fresh
        } else {
            let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            scContent = (windows: content?.windows ?? [], at: Date())
        }
        guard let scWindow = scContent?.windows.first(where: { $0.windowID == windowID }) else {
            return nil
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        let scale: CGFloat = 2 // retina output
        config.width = Int(max(16, size.width * scale))
        config.height = Int(max(16, size.height * scale))
        config.showsCursor = false
        config.captureResolution = .best

        guard let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                        configuration: config) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage,
                            size: NSSize(width: size.width, height: size.height))
        return image
    }

    /// CGWindowListCreateImage fallback (deprecated since macOS 14, still
    /// functional on macOS 13 which is our minimum target).
    @available(macOS, introduced: 13.0, deprecated: 14.0)
    nonisolated static func captureWithLegacyCG(windowID: CGWindowID, size: CGSize) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(.null,
                                                    .optionIncludingWindow,
                                                    windowID,
                                                    [.boundsIgnoreFraming, .bestResolution]) else {
            return nil
        }
        let width = CGFloat(cgImage.width) / 2
        let height = CGFloat(cgImage.height) / 2
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}
