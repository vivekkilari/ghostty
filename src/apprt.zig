//! "apprt" is the "application runtime" package. This abstracts the
//! application runtime and lifecycle management such as creating windows,
//! getting user input (mouse/keyboard), etc.
//!
//! This enables compile-time interfaces to be built to swap out the underlying
//! application runtime. For example: pure macOS Cocoa, GTK+, browser, etc.
//!
//! The goal is to have different implementations share as much of the core
//! logic as possible, and to only reach out to platform-specific implementation
//! code when absolutely necessary.
const std = @import("std");
const builtin = @import("builtin");
const build_config = @import("build_config.zig");

const structs = @import("apprt/structs.zig");

pub const action = @import("apprt/action.zig");
pub const ipc = @import("apprt/ipc.zig");
pub const gtk = @import("apprt/gtk.zig");
pub const gtk_ng = @import("apprt/gtk-ng.zig");
pub const none = @import("apprt/none.zig");
pub const browser = @import("apprt/browser.zig");
pub const embedded = @import("apprt/embedded.zig");
pub const surface = @import("apprt/surface.zig");
pub const winui = @import("apprt/winui.zig");

pub const Action = action.Action;
pub const Target = action.Target;

pub const ContentScale = structs.ContentScale;
pub const Clipboard = structs.Clipboard;
pub const ClipboardRequest = structs.ClipboardRequest;
pub const ClipboardRequestType = structs.ClipboardRequestType;
pub const ColorScheme = structs.ColorScheme;
pub const CursorPos = structs.CursorPos;
pub const IMEPos = structs.IMEPos;
pub const Selection = structs.Selection;
pub const SurfaceSize = structs.SurfaceSize;

/// The implementation to use for the app runtime. This is comptime chosen
/// so that every build has exactly one application runtime implementation.
/// Note: it is very rare to use Runtime directly; most usage will use
/// Window or something.
pub const runtime = switch (build_config.artifact) {
    .exe => switch (build_config.app_runtime) {
        .none => none,
        .gtk => gtk,
        .@"gtk-ng" => gtk_ng,
        .winui => winui,
    },
    .lib => embedded,
    .wasm_module => browser,
};

pub const App = runtime.App;
pub const Surface = runtime.Surface;

/// Runtime is the runtime to use for Ghostty. All runtimes do not provide
/// equivalent feature sets.
pub const Runtime = enum {
    /// Will not produce an executable at all when `zig build` is called.
    /// This is only useful if you're only interested in the lib only (macOS).
    none,

    /// GTK-backed. Rich windowed application. GTK is dynamically linked.
    gtk,

    /// GTK4. The "-ng" variant is a rewrite of the GTK backend using
    /// GTK-native technologies such as full GObject classes, Blueprint
    /// files, etc.
    @"gtk-ng",

    winui,

    pub fn default(target: std.Target) Runtime {
        // The Linux default is GTK because it is full featured.
        if (target.os.tag == .linux) return .gtk;
        if (target.os.tag == .windows) return .winui;

        // Otherwise, we do NONE so we don't create an exe and we
        // create libghostty.
        return .none;
    }
};

test {
    _ = Runtime;
    _ = runtime;
    _ = action;
    _ = structs;
}
