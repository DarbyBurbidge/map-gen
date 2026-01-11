const std = @import("std");
const assert = std.debug.assert;
const rl = @import("raylib");
const rg = @import("raygui");
const Rectangle = rl.Rectangle;
const Allocator = std.mem.Allocator;

const Grid = @import("Grid.zig");
const Algorithm = @import("Algorithm.zig");
const Button = @import("Button.zig");
const ButtonBox = Button.ButtonBox;
const PathingAlgo = Algorithm.Pathing.Algorithm;
const Mobility = Algorithm.Pathing.Mobility;
const TraversalType = @import("Tile.zig").TraversalType;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const screenWidth = 800;
    const screenHeight = 640;

    rl.initWindow(screenWidth, screenHeight, "map-gen");
    defer rl.closeWindow();

    // Load the font
    var font: rl.Font = rl.loadFontEx(
        "/home/darby/Projects/systems/map-gen/src/resources/november.ttf",
        24,
        null,
    ) catch |err| {
        return err;
    };
    if (font.texture.id == 0) {
        std.debug.print("could not load font\n", .{});
    }

    rl.setTargetFPS(60);

    const tileSize = 16;
    const background: rl.Color = .black;
    const roundness: f32 = 0.2;
    const segments: f32 = 0.0;
    var heat_map_on: bool = false;
    var start_selected = false;
    var start_idx: i16 = -1;
    var end_selected = false;
    var end_idx: i16 = -1;
    var pathing_type: TraversalType = .walk;
    var path_algo: PathingAlgo = .dfs;
    var mobility_type: Mobility = .orthogonal;
    var map = try Grid.init(screenWidth, screenHeight - 128, tileSize, &allocator);
    var button_box = ButtonBox{
        .rect = rl.Rectangle{
            .x = 0,
            .y = @floatFromInt(map.height * 32),
            .width = 800,
            .height = @floatFromInt(screenHeight - (map.height * tileSize)),
        },
        .inner_rect = rl.Rectangle{
            .x = 2,
            .y = @floatFromInt((map.height * 32) + 2),
            .width = 796,
            .height = @floatFromInt((screenHeight - (map.height * tileSize) - 4)),
        },
        .color = .beige,
        .border_color = .brown,
    };
    var traversal_btn = Button.TraversalButton.init(32, screenHeight - 112, 160, 32, font);
    var path_mobility_btn = Button.PathMobilityButton.init(32 + 160 + 32, screenHeight - 112, 160, 32, font);
    var path_algo_btn = Button.PathingButton.init(32, screenHeight - 48, 160, 32, font, path_algo);
    var reset_path_btn = Button.ResetButton.init(32 + 160 + 32, screenHeight - 48, 160, 32, font);
    var reset_map_btn = Button.ResetButton.init(32 + 160 + 32 + 160 + 32, screenHeight - 48, 160, 32, font);
    var map_algo_btn = Button.MapAlgorithmButton.init(32 + 160 + 32 + 160 + 32 + 160 + 32, screenHeight - 112, 160, 32, font);
    var map_gen_btn = Button.MapGenButton.init(32 + 160 + 32 + 160 + 32 + 160 + 32, screenHeight - 48, 160, 32, font);
    var heat_map_btn = Button.HeatMapButton.init(32 + 160 + 32 + 160 + 32, screenHeight - 112, 160, 32, font);
    while (!rl.windowShouldClose()) {
        var mouse_idx: i32 = -1;
        // Begin drawing
        rl.beginDrawing();
        // Set background
        rl.clearBackground(background);
        // End drawing

        for (map.tiles, 0..) |*tile, idx| {
            // Update
            const mousePoint = rl.getMousePosition();
            // Check if the mouse is over the "button" rectangle
            if (rl.checkCollisionPointRec(mousePoint, tile.rect)) {
                mouse_idx = @intCast(idx);
                // Check if the left mouse button was pressed in this specific frame
                if (rl.isMouseButtonPressed(.left)) {
                    // Perform button action here
                    if (start_selected and start_idx == idx) {
                        start_selected = false;
                        start_idx = -1;
                        tile.*.set_state(.none);
                    } else if (end_selected and end_idx == idx) {
                        end_selected = false;
                        end_idx = -1;
                        tile.*.set_state(.none);
                    } else if (!start_selected) {
                        tile.*.set_state(.start);
                        //tile.*.color = .green;
                        start_selected = true;
                        start_idx = @intCast(idx);
                    } else if (!end_selected) {
                        tile.*.set_state(.end);
                        end_selected = true;
                        end_idx = @intCast(idx);
                    }
                }
            }
            tile.draw();
        }

        const mousePoint = rl.getMousePosition();
        if (rl.checkCollisionPointRec(mousePoint, traversal_btn.border_box)) {
            if (rl.isMouseButtonPressed(.left)) {
                traversal_btn.on_click(&pathing_type);
            }
        }
        if (rl.checkCollisionPointRec(mousePoint, reset_path_btn.border_box)) {
            if (rl.isMouseButtonPressed(.left)) {
                reset_visited(map);
                start_selected = false;
                end_selected = false;
            }
        }
        if (rl.checkCollisionPointRec(mousePoint, path_algo_btn.border_box)) {
            if (rl.isMouseButtonPressed(.left)) {
                path_algo_btn.on_click(&path_algo);
            }
        }
        if (rl.checkCollisionPointRec(mousePoint, path_mobility_btn.border_box)) {
            if (rl.isMouseButtonPressed(.left)) {
                path_mobility_btn.on_click(&mobility_type);
            }
        }
        if (rl.checkCollisionPointRec(mousePoint, map_gen_btn.border_box)) {
            if (rl.isMouseButtonPressed(.left)) {
                try Algorithm.Generation.c_a(map, 2, allocator);
            }
        }
        if (rl.checkCollisionPointRec(mousePoint, heat_map_btn.border_box)) {
            if (rl.isMouseButtonPressed(.left)) {
                heat_map_on = !heat_map_on;
            }
        }
        if (heat_map_on) {
            if (mouse_idx > 0) {
                var d_map = try Algorithm.Pathing.get_dijkstra_map(map, mouse_idx, pathing_type, mobility_type, allocator);
                d_map.set_font(font);
                d_map.draw();
            }
        }

        rl.drawRectangleRounded(button_box.rect, roundness, @as(i32, @intFromFloat(segments)), .fade(button_box.border_color, 1.0));
        rl.drawRectangleRounded(button_box.inner_rect, roundness, @as(i32, @intFromFloat(segments)), .fade(button_box.color, 1.0));
        traversal_btn.draw();
        reset_path_btn.draw();
        path_algo_btn.draw();
        map_algo_btn.draw();
        map_gen_btn.draw();
        heat_map_btn.draw();
        path_mobility_btn.draw();
        reset_map_btn.draw();
        if (start_selected and end_selected and start_idx != -1 and end_idx != -1) {
            switch (path_algo) {
                .dfs => {
                    try Algorithm.Pathing.dfs(map, @intCast(start_idx), @intCast(end_idx), pathing_type, mobility_type, allocator);
                },
                .bfs => {
                    try Algorithm.Pathing.bfs(map, @intCast(start_idx), @intCast(end_idx), pathing_type, mobility_type, allocator);
                },
                .dijkstra => {
                    try Algorithm.Pathing.dijkstra(map, @intCast(start_idx), @intCast(end_idx), pathing_type, mobility_type, allocator);
                },
                .a_star => {
                    try Algorithm.Pathing.a_star(map, @intCast(start_idx), @intCast(end_idx), pathing_type, mobility_type, allocator);
                },
            }
            start_idx = -1;
            end_idx = -1;
        }
        rl.endDrawing();
    }
}

fn reset_visited(grid: Grid) void {
    for (grid.tiles) |*tile| {
        tile.set_state(.none);
    }
}

test "simple test" {}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
