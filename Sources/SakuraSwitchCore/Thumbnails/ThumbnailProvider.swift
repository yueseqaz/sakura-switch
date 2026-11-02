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

    private struct CaptureKey: Hashable {
        let windowID: CGWindowID
        let width: Int
        let height: Int
    }

    private var cache: [CaptureKey: Entry] = [:]
    private var inFlight: [CaptureKey: Task<CGImage?, Never>] = [:]
    private var generation = 0
    private var contentTask: Task<[SCWindow], Error>?

    /// Cached shareable content (SC enumeration is expensive).
    private var scContent: (windows: [SCWindow], at: Date)?

    public init() {}

    // MARK: - Public

    /// Latest thumbnail for a window, or nil (caller shows the app icon).
    public func thumbnail(for window: WindowModel, size: CGSize) async -> NSImage? {
        guard ScreenCapturePermission.isGranted else { return nil }
        // Enlarged hover previews need a separate capture at their own resolution.
        let key = CaptureKey(windowID: window.windowID, width: Int(size.width.rounded(.up)), height: Int(size.height.rounded(.up)))
        if let entry = cache[key],
           Date().timeIntervalSince(entry.at) < Self.ttl {
            return entry.image
        }
        // Coalesce duplicate requests for the same window.
        if let task = inFlight[key] {
            guard let image = await task.value, !task.isCancelled else { return nil }
            return NSImage(cgImage: image, size: size)
        }
        let captureGeneration = generation
        let task = Task { await self.capture(windowID: window.windowID, size: size) }
        inFlight[key] = task
        let captured = await task.value
        guard captureGeneration == generation, !task.isCancelled else { return nil }
        inFlight.removeValue(forKey: key)
        if let captured {
            let image = NSImage(cgImage: captured, size: size)
            cache[key] = Entry(image: image, at: Date())
            return image
        } else {
            Log.thumbnails.debug("Capture failed for a window")
        }
        return nil
    }

    public func invalidateAll() {
        generation += 1
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        contentTask?.cancel()
        contentTask = nil
        cache.removeAll()
        scContent = nil
    }

    public func invalidate(windowID: CGWindowID) {
        for key in inFlight.keys.filter({ $0.windowID == windowID }) {
            inFlight.removeValue(forKey: key)?.cancel()
        }
        cache = cache.filter { $0.key.windowID != windowID }
    }

    // MARK: - Capture

    private func capture(windowID: CGWindowID, size: CGSize) async -> CGImage? {
        if #available(macOS 14.0, *) {
            return await captureWithScreenCaptureKit(windowID: windowID, size: size)
        } else {
            return Self.captureWithLegacyCG(windowID: windowID, size: size)
        }
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(windowID: CGWindowID, size: CGSize) async -> CGImage? {
        // Refresh the SC window list at most every 2 seconds.
        if let scContent, Date().timeIntervalSince(scContent.at) < 2 {
            // still fresh
        } else {
            let task: Task<[SCWindow], Error>
            if let contentTask {
                task = contentTask
            } else {
                task = Task {
                    try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false).windows
                }
                contentTask = task
            }
            do {
                let windows = try await task.value
                guard !task.isCancelled else { return nil }
                scContent = (windows: windows, at: Date())
                contentTask = nil
            } catch {
                guard !task.isCancelled else { return nil }
                contentTask = nil
                let failure = error as NSError
                Log.thumbnails.error("Window capture enumeration failed: \(failure.domain, privacy: .public) code=\(failure.code)")
                return nil
            }
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

        let cgImage: CGImage
        do {
            cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            let failure = error as NSError
            Log.thumbnails.error("Window capture failed: \(failure.domain, privacy: .public) code=\(failure.code)")
            return nil
        }
        return cgImage
    }

    /// CGWindowListCreateImage fallback (deprecated since macOS 14, still
    /// functional on macOS 13 which is our minimum target).
    @available(macOS, introduced: 13.0, deprecated: 14.0)
    nonisolated static func captureWithLegacyCG(windowID: CGWindowID, size: CGSize) -> CGImage? {
        guard let cgImage = CGWindowListCreateImage(.null,
                                                    .optionIncludingWindow,
                                                    windowID,
                                                    [.boundsIgnoreFraming, .bestResolution]) else {
            return nil
        }
        return cgImage
    }
}
