//! Rendering implementation for OpenGL.
pub const OpenGL = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const font = @import("../font/main.zig");
const renderer = @import("../renderer.zig");
const terminal = @import("../terminal/main.zig");
const CellProgram = @import("opengl/CellProgram.zig");

/// Responsible for building the frame state on the CPU side. This effectively
/// takes a snapshot of terminal state and configuration and converts it
/// into a format that can be easily submitted to the GPU.
pub const FrameBuilder = struct {
    /// The size of everything.
    size: renderer.Size,

    /// Font information
    font_grid: *font.SharedGrid,
    font_shaper: font.Shaper,

    /// Build the frame state from the given scene state.
    ///
    /// The result is written to the "frame" output parameter. This should
    /// at least be initialized to empty. This can point to prior to frame
    /// state if you want to be more memory efficient.
    ///
    /// If this results in an error, the frame state should be considered
    /// corrupt and should not be used for drawing. The frame state CAN be
    /// reused in a future build call without being reset, though.
    pub fn build(
        self: *FrameBuilder,
        alloc: Allocator,
        frame: *FrameState,
        scene: *renderer.State,
    ) !void {
        // Grab our data that we need within the critical section.
        var critical: Critical = critical: {
            scene.mutex.lock();
            defer scene.mutex.unlock();
            break :critical .{};
        };

        try self.buildCells(alloc, frame, &critical);
    }

    // TODO: extended padding
    // TODO: preedit
    fn buildCells(
        self: *FrameBuilder,
        alloc: Allocator,
        frame: *FrameState,
        critical: *const Critical,
    ) !void {
        // Create an arena for all our temporary allocations while rebuilding
        var arena = ArenaAllocator.init(alloc);
        defer arena.deinit();
        const arena_alloc = arena.allocator();

        // Common, trivial data we need often.
        const grid_size = self.size.grid();
        const screen: *terminal.Screen = &critical.screen;

        // Clear our cells but retain the memory since in most cases
        // we're drawing almost the exact same cell count every frame.
        frame.cells_bg.clearRetainingCapacity();
        frame.cells_fg.clearRetainingCapacity();

        // These are all the foreground cells underneath the cursor.
        //
        // We keep track of these so that we can invert the colors and move them
        // in front of the block cursor so that the character remains visible.
        //
        // We init with a capacity of 4 to account for decorations such
        // as underline and strikethrough, as well as combining chars.
        var cursor_cells: FrameState.CellList = try .initCapacity(arena_alloc, 4);
        defer cursor_cells.deinit(arena_alloc);

        // We rebuild the cells row-by-row because we do font shaping by row.
        var row_it = screen.pages.rowIterator(
            .left_up,
            .{ .viewport = .{} },
            null,
        );

        // Our end y is the smaller of the actual screen rows or the rows
        // we can fit in our viewport. Its possible to desync for a frame
        // or two so this let's us render correctly.
        var y: terminal.size.CellCountInt = @min(
            screen.pages.rows,
            grid_size.rows,
        );
        while (row_it.next()) |row| {
            // The viewport may have more rows than our cell contents,
            // so we need to break from the loop early if we hit y = 0.
            if (y == 0) break;
            y -= 1;

            // True if we want to do font shaping around the cursor. We want to
            // do font shaping as long as the cursor is enabled.
            const shape_cursor = screen.viewportIsBottom() and
                y == screen.cursor.y;

            // If this is the row with our cursor, then we may have to modify
            // the cell with the cursor.
            const start_i: usize = self.cells.items.len;
            defer if (shape_cursor and critical.cursor_style == .block) {
                const x = screen.cursor.x;
                const wide = row.cells(.all)[x].wide;
                const min_x = switch (wide) {
                    .narrow, .spacer_head, .wide => x,
                    .spacer_tail => x -| 1,
                };
                const max_x = switch (wide) {
                    .narrow, .spacer_head, .spacer_tail => x,
                    .wide => x +| 1,
                };
                for (self.cells.items[start_i..]) |cell| {
                    if (cell.grid_col < min_x or cell.grid_col > max_x) continue;
                    if (cell.mode.isFg()) {
                        cursor_cells.append(arena_alloc, cell) catch {
                            // We silently ignore if this fails because
                            // worst case scenario some combining glyphs
                            // aren't visible under the cursor '\_('-')_/'
                        };
                    }
                }
            };

            // We need to get this row's selection if there is one for proper
            // run splitting.
            const row_selection = sel: {
                const sel = screen.selection orelse break :sel null;
                const pin = screen.pages.pin(.{ .viewport = .{ .y = y } }) orelse
                    break :sel null;
                break :sel sel.containedRow(screen, pin) orelse null;
            };
            _ = row_selection;

            // Iterator of runs for shaping.
            // var run_iter = self.font_shaper.runIterator(
            //     self.font_grid,
            //     screen,
            //     row,
            //     row_selection,
            //     if (shape_cursor) screen.cursor.x else null,
            // );
            // var shaper_run: ?font.shape.TextRun = try run_iter.next(self.alloc);
            // var shaper_cells: ?[]const font.shape.Cell = null;
            // var shaper_cells_i: usize = 0;

            // If our viewport is wider than our cell contents buffer,
            // we still only process cells up to the width of the buffer.
            const row_cells_all = row.cells(.all);
            const row_cells = row_cells_all[0..@min(row_cells_all.len, grid_size.columns)];
            for (row_cells, 0..) |*cell, x| {
                _ = cell;
                _ = x;
            }
        }
    }

    /// Data we extract from the scene state while locking the mutex.
    /// We want to hold the lock for as little time as possible so we
    /// copy as much as we can into this intermediate struct.
    const Critical = struct {
        /// The terminal screen contents.
        screen: terminal.Screen,

        /// The style to use for the cursor. This will be null if we're not
        /// rendering a cursor (e.g. cursor not in the viewport, terminal
        /// state disabled the cursor, etc.)
        cursor_style: ?renderer.CursorStyle,

        pub fn deinit(self: *Critical) void {
            self.screen.deinit();
        }
    };
};

/// The per-frame CPU state.
pub const FrameState = struct {
    /// The set of cells to render with the Cell shader.
    cells_bg: CellList,
    cells_fg: CellList,

    pub const empty: FrameState = .{
        .cells_bg = .empty,
        .cells_fg = .empty,
    };

    const CellList = std.ArrayListUnmanaged(CellProgram.Cell);
};

test "OpenGL FrameBuilder: build" {
    const testing = std.testing;
    const alloc = testing.allocator;
    try testing.expect(true);

    var font_grid: font.SharedGrid = grid: {
        const lib: font.Library = try .init();
        var c: font.Collection = .init();
        var r: font.CodepointResolver = .{ .collection = c };
        errdefer r.deinit(alloc);

        // Setup our collection with the fonts we want
        c.load_options = .{ .library = lib };
        _ = try c.add(alloc, .regular, .{ .loaded = try .init(
            lib,
            font.embedded.regular,
            .testDefault,
        ) });

        break :grid try .init(alloc, r);
    };
    defer font_grid.deinit(alloc);
}
