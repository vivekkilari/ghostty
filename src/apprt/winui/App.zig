/// This is the main Windows entrypoint to the apprt for Ghostty. 
/// Ghostty will initialize this in main to start the application.
const App = @This();

// const std = @import("std");
// const builtin = @import("builtin");
// const Allocator = std.mem.Allocator;
// const apprt = @import("../../apprt.zig");
// const configpkg = @import("../../config.zig");
// const internal_os = @import("../../os/main.zig");
// const Config = configpkg.Config;
// const CoreApp = @import("../../App.zig");
//
// const Application = {};
// const Surface = @import("Surface.zig");
//
// const log = std.log.scoped(.gtk);
//
// pub const must_draw_from_app_thread = true;
// app: *Application,
//
// pub fn init(
//     self: *App,
//     core_app: *CoreApp,
//
//     // Required by the apprt interface but we don't use it.
//     opts: struct {},
// ) !void {
//     _ = opts;
//
//     const app: *Application = try .new(self, core_app);
//     errdefer app.unref();
//     self.* = .{ .app = app };
//     return;
// }
//
// pub fn run(self: *App) !void {
//     try self.app.run();
// }
//
// pub fn terminate(self: *App) void {
//     // We force deinitialize the app. We don't unref because other things
//     // tend to have a reference at this point, so this just forces the
//     // disposal now.
//     self.app.deinit();
// }
//
// /// Called by CoreApp to wake up the event loop.
// pub fn wakeup(self: *App) void {
//     self.app.wakeup();
// }
//
// pub fn performAction(
//     self: *App,
//     target: apprt.Target,
//     comptime action: apprt.Action.Key,
//     value: apprt.Action.Value(action),
// ) !bool {
//     return try self.app.performAction(target, action, value);
// }
//
// /// Redraw the inspector for the given surface.
// pub fn redrawInspector(self: *App, surface: *Surface) void {
//     _ = self;
//     _ = surface;
// }
