// std
const std = @import("std");
const Init = std.process.Init;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

// raylib
const rl = @import("raylib");
const rg = @import("raygui");
const Rectangle = rl.Rectangle;

// other
const Grid = @import("Grid.zig");
const GridConfig = Grid.Config;
const TraversalType = @import("Tile.zig").TraversalType;
const EventLog = @import("EventLog.zig");
const LogConfig = EventLog.Config;
const Algorithm = @import("Algorithm.zig");
const PathingAlgo = Algorithm.Pathing.Algorithm;
const Mobility = Algorithm.Pathing.Mobility;
const GenerationAlgo = Algorithm.Generation.Algorithm;
const ResetMapAlgoState = Algorithm.Generation.MapState;
const Button = @import("Button.zig");
const ButtonBox = Button.ButtonBox;

pub fn main(init: Init) !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const io = init.io;
    const allocator = gpa.allocator();
    const screen_pw = 1920; // 80 * 24
    const screen_ph = 1080; // 45 * 24
    const tile_ps = 24;
    const screen_tw = @divFloor(screen_pw, tile_ps);
    const screen_th = @divFloor(screen_ph, tile_ps);

    rl.setTargetFPS(60);
    // init I/O
    rl.initWindow(screen_pw, screen_ph, "map-gen");
    defer rl.closeWindow();
    rl.setWindowState(.{.window_topmost = true});

    rl.initAudioDevice();
    defer rl.closeAudioDevice();
    rl.setMasterVolume(0.5);

    // default configuration
    const grid_tw = 50;
    const grid_th = 30;
    const map_padding_x_ts = 3;
    const map_padding_y_ts = 2;
    const map_tw = grid_tw + map_padding_x_ts * 2;
    const map_th = grid_th + map_padding_y_ts * 2;
    const btn_box_tw = screen_tw - map_tw;
    const btn_box_th = screen_th - map_th;
    const info_box_tw = screen_tw - map_tw;
    const info_box_th = map_th;
    const logger_tw = map_tw;
    const logger_th = screen_th - map_th;
    const background: rl.Color = .black;
    const btn_tw = 6;
    const btn_th = 2;

    // state
    var start_selected = false;
    var start_idx: i16 = -1;
    var end_selected = false;
    var end_idx: i16 = -1;
    var reset_path: bool = false;
    var reset_map: bool = false;
    var generate_map: bool = false;
    var heatmap_on: bool = false;
    var traversal_type: TraversalType = .walk;
    var path_algo: PathingAlgo = .a_star;
    var map_state = ResetMapAlgoState{
        .algo = .ca,
        .reset = false,
    };
    var mobility_type: Mobility = .orthogonal;

    // load external resources
    // music
    const veridis_quo = try rl.loadMusicStream("/home/darby/Projects/systems/map-gen/src/resources/veridis_quo.ogg");
    defer rl.unloadMusicStream(veridis_quo);
    rl.playMusicStream(veridis_quo);

    // font
    const font: rl.Font = rl.loadFontEx(
        "/home/darby/Projects/systems/map-gen/src/resources/november.ttf",
        tile_ps,
        null,
    ) catch |err| {
        return err;
    };

    if (font.texture.id == 0) {
        std.debug.print("could not load font\n", .{});
    }

    const border_tileset: rl.Texture2D = try rl.loadTexture("/home/darby/Projects/systems/map-gen/src/resources/border_pipe_colorized.bmp");
    const padding_tileset: rl.Texture2D = try rl.loadTexture("/home/darby/Projects/systems/map-gen/src/resources/bricks_w_ends_colorized.bmp");
    const button_tileset: rl.Texture2D = try rl.loadTexture("/home/darby/Projects/systems/map-gen/src/resources/button_colorized.bmp");
    const tile_tileset: rl.Texture2D = try rl.loadTexture("/home/darby/Projects/systems/map-gen/src/resources/dungeons_and_caves.bmp");

    // configure UI and game components
    // create map grid
    const map = try Grid.init(
        GridConfig{
        .rect = rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = map_tw * tile_ps,
            .height = map_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .border_tileset = border_tileset,
        .padding_tileset = padding_tileset,
        .tile_tileset = tile_tileset,
        .padding_x = map_padding_x_ts,
        .padding_y = map_padding_y_ts,
        .tw = grid_tw,
        .th = grid_th,
        },
        io,
        allocator,
    );
    // create event log
    var event_log = EventLog.init(
        LogConfig{
            .font = font,
            .rect = rl.Rectangle{
                .x = 0,
                .y = (screen_th - logger_th) * tile_ps,
                .width = logger_tw * tile_ps,
                .height = logger_th * tile_ps
            },
            .tile_ps = tile_ps,
            .border_tileset = border_tileset,
        },
        io,
        allocator
    );

    // create button panel
    var info_box = ButtonBox{
        .allocator = allocator,
        .btns = .empty,
        .rect = rl.Rectangle{
            .x = (screen_tw - info_box_tw) * tile_ps,
            .y = 0.0,
            .width = info_box_tw * tile_ps,
            .height = info_box_th * tile_ps,
        },
        .color = .gray,
        .btn_tw = btn_tw,
        .btn_th = btn_th,
        .tile_ps = tile_ps,
        .border_tileset = border_tileset,
    };
    var button_box = ButtonBox{
        .allocator = allocator,
        .btns = .empty,
        .rect = rl.Rectangle{
            .x = (screen_tw - btn_box_tw) * tile_ps,
            .y = (screen_th - btn_box_th) * tile_ps,
            .width = btn_box_tw * tile_ps,
            .height = btn_box_th * tile_ps,
        },
        .color = .brown,
        .btn_tw = btn_tw,
        .btn_th = btn_th,
        .tile_ps = tile_ps,
        .border_tileset = border_tileset,
    };
    const first_col_x = (map_tw + 2) * tile_ps;
    const second_col_x = (map_tw + 2 + btn_tw) * tile_ps + tile_ps;
    const third_col_x = (map_tw + 2 + 2 * btn_tw) * tile_ps + tile_ps * 2;
    const first_row_y = (screen_th - 4) * tile_ps;
    const second_row_y = (screen_th - 4 - 3) * tile_ps;
    const third_row_y = (screen_th - 4 - 6) * tile_ps;

    // traversal
    try button_box.add_btn(.{
        .rect = .{
            .x = first_col_x,
            .y = third_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "a star"[0..],
        .color = .dark_gray,
        .text_color = .gold,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .path_algo,
        .state = &path_algo
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = first_col_x,
            .y = second_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "walking"[0..],
        .color = .light_gray,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .traversal,
        .state = &traversal_type
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = second_col_x,
            .y = second_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "ortho"[0..],
        .color = .light_gray,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .mobility,
        .state = &mobility_type,
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = first_col_x,
            .y = first_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "reset"[0..],
        .color = .red,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .toggle,
        .state = &reset_path,
    });
    // map gen
    try button_box.add_btn(.{
        .rect = .{
            .x = third_col_x,
            .y = first_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "reset"[0..],
        .color = .red,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .toggle,
        .state = &reset_map,
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = third_col_x,
            .y = third_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps, 
        },
        .tile_ps = tile_ps,
        .message = "cellular"[0..],
        .color = .light_gray,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .map_algo,
        .state = &map_state,
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = third_col_x,
            .y = second_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "create"[0..],
        .color = .green,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .toggle,
        .state = &generate_map,
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = second_col_x,
            .y = third_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "heatmap"[0..],
        .color = .orange,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click_type = .toggle,
        .state = &heatmap_on,
    });
    
    // game loop
    while (!rl.windowShouldClose()) {
        var mouse_idx: i32 = -1;
        // play music
        rl.updateMusicStream(veridis_quo);
        // Begin drawing
        rl.beginDrawing();
        // Set background
        rl.clearBackground(background);

        for (map.tiles, 0..) |*tile, idx| {
            // Update
            const mousePoint = rl.getMousePosition();
            // Check if the mouse is over the "button" rectangle
            if (rl.checkCollisionPointRec(mousePoint, tile.dest_rect)) {
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
        }
        switch (map_state.algo) {
            .ca, .bsp, .noise => {
                map.draw();
            },
            .voronoi => {
                map.draw_custom();
            },
        }

        if (rl.isKeyPressed(.f11)) {
            if (rl.isWindowState(.{.window_undecorated = true})) {
                rl.clearWindowState(.{.window_undecorated = true});
            } else {
                rl.setWindowState(.{.window_undecorated = true});
            }
        }

        const m_cursor = rl.getMousePosition();
        if (rl.checkCollisionPointRec(m_cursor, button_box.rect)) {
            if (rl.isMouseButtonPressed(.left)) {
                button_box.on_click(m_cursor);
            }
        }
        if (reset_path or reset_map) {
            reset_visited(map);
            start_selected = false;
            end_selected = false;
            reset_path = false;
        }
        if (reset_map or map_state.reset) {
            map.clear();
            reset_map = false;
            map_state.reset = false;
        }
        if (generate_map) {
            switch (map_state.algo) {
                .ca => {
                    try Algorithm.Generation.c_a(map, 2, io, allocator);
                },
                .bsp => {
                    try Algorithm.Generation.bsp(map, io, allocator);
                },
                .voronoi => {
                    try Algorithm.Generation.voronoi(map, io, allocator);
                },
                .noise => {
                    try Algorithm.Generation.noise(map, io, allocator);
                }
            }
            generate_map = false;
        }
        if (heatmap_on) {
            if (mouse_idx > 0) {
                var d_map = try Algorithm.Pathing.get_dijkstra_map(map, tile_ps, mouse_idx, traversal_type, mobility_type, allocator);
                d_map.set_font(font);
                d_map.draw();
            }
        }

        info_box.draw();
        button_box.draw();
        event_log.draw();
        if (start_selected and end_selected and start_idx != -1 and end_idx != -1) {
            switch (path_algo) {
                .dfs => {
                    try Algorithm.Pathing.dfs(map, @intCast(start_idx), @intCast(end_idx), traversal_type, mobility_type, allocator);
                },
                .bfs => {
                    try Algorithm.Pathing.bfs(map, @intCast(start_idx), @intCast(end_idx), traversal_type, mobility_type, allocator);
                },
                .dijkstra => {
                    try Algorithm.Pathing.dijkstra(map, @intCast(start_idx), @intCast(end_idx), traversal_type, mobility_type, allocator);
                },
                .a_star => {
                    try Algorithm.Pathing.a_star(map, @intCast(start_idx), @intCast(end_idx), traversal_type, mobility_type, allocator);
                },
            }
            start_idx = -1;
            end_idx = -1;
        }
        // End drawing
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
