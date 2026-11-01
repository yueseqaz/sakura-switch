import os

/// OSLog wrappers, one logger per module.
/// Production logs must not contain window titles or other user content;
/// debug-only details are gated behind `#if DEBUG`.
public enum Log {
    private static let subsystem = "com.yueseqaz.sakuraswitch"

    public static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")
    public static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    public static let windowEnumeration = Logger(subsystem: subsystem, category: "WindowEnumeration")
    public static let thumbnails = Logger(subsystem: subsystem, category: "Thumbnails")
    public static let switcher = Logger(subsystem: subsystem, category: "Switcher")
    public static let settings = Logger(subsystem: subsystem, category: "Settings")
}
