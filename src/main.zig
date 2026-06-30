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
const MiniMap = @import("MiniMap.zig");
const MiniMapConfig = MiniMap.Config;
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
const toggle_on_click = Button.toggle_on_click;
const mobility_on_click = Button.mobility_on_click;
const map_algo_on_click = Button.map_algo_on_click;
const path_algo_on_click = Button.path_algo_on_click;
const traversal_on_click = Button.traversal_on_click;
const Actor = @import("Actor.zig");
const Health = @import("Health.zig");
const Menu = @import("Menu.zig");
const MenuState = Menu.State;


pub fn main(init: Init) !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const io = init.io;
    const allocator = gpa.allocator();
    const screen_pw = 1920; // 80 * 24
    const screen_ph = 1080; // 45 * 24
    const tile_ps = 24;
    const screen_tw = @divFloor(screen_pw, tile_ps);
    const screen_th = @divFloor(screen_ph, tile_ps);

    // init I/O
    rl.initWindow(screen_pw, screen_ph, "map-gen");
    defer rl.closeWindow();
    rl.setWindowState(.{.window_topmost = true});
    rl.setTargetFPS(60);
    rl.setExitKey(.null);

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
    const minimap_box_tw = screen_tw - map_tw;
    const minimap_box_th = 15;
    const info_box_tw = screen_tw - map_tw;
    const info_box_th = map_th - minimap_box_th;
    const logger_tw = map_tw;
    const logger_th = screen_th - map_th;
    const background: rl.Color = .black;
    const btn_tw = 6;
    const btn_th = 2;

    // state
    var menu_state: MenuState = .main_menu;
    var map_state = ResetMapAlgoState{
        .algo = .ca,
        .reset = false,
    };
    var start_selected = false;
    var set_player_position = false;
    var playing_level = false;
    var request_close = false;
    var start_idx: i16 = -1;
    var end_selected = false;
    var end_idx: i16 = -1;
    var reset_path: bool = false;
    var reset_map: bool = false;
    var generate_map: bool = false;
    var heatmap_on: bool = false;
    var traversal_type: TraversalType = .walk;
    var path_algo: PathingAlgo = .a_star;
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
    const player_tileset: rl.Texture2D = try rl.loadTexture("/home/darby/Projects/systems/map-gen/src/resources/player.bmp");
    const menu_background: rl.Texture2D = try rl.loadTexture("/home/darby/Projects/systems/map-gen/src/resources/menu.bmp");

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

    const minimap = MiniMap.init(
        MiniMapConfig{
            .tiles = map.tiles,
            .tile_ps = tile_ps,
            .map_width = grid_tw,
            .rect = rl.Rectangle{
                .x = map_tw * tile_ps,
                .y = info_box_th * tile_ps,
                .width = minimap_box_tw * tile_ps,
                .height = minimap_box_th * tile_ps
            },
            .color = .black,
            .border_tileset = border_tileset,
        },
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
    const info_box = ButtonBox{
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
        .on_click = path_algo_on_click,
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
        .on_click = traversal_on_click,
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
        .on_click = mobility_on_click,
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
        .on_click = toggle_on_click,
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
        .on_click = toggle_on_click,
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
        .on_click = map_algo_on_click,
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
        .on_click = toggle_on_click,
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
        .on_click = toggle_on_click,
        .state = &heatmap_on,
    });
    try button_box.add_btn(.{
        .rect = .{
            .x = second_col_x,
            .y = first_row_y,
            .width = btn_tw * tile_ps,
            .height = btn_th * tile_ps,
        },
        .tile_ps = tile_ps,
        .message = "play"[0..],
        .color = .green,
        .text_color = .dark_gray,
        .font = font,
        .tileset = button_tileset,
        .logger = &event_log,
        .on_click = toggle_on_click,
        .state = &set_player_position,
    });

    var player = Actor{
        .name = "Boris"[0..],
        .hp = Health{
            .max = 100,
            .curr = 100,
        },
        .location = .{
            .x = -tile_ps,
            .y = -tile_ps,
        },
        .tileset = player_tileset,
    };
    
    var main_menu = try Menu.init(screen_pw, screen_ph, btn_tw * tile_ps, btn_th * tile_ps, tile_ps, &menu_state, font, button_tileset, menu_background, &request_close, allocator);
    // game loop
    while (!rl.windowShouldClose() and !request_close) {
        var mouse_idx: i32 = -1;
        // Begin drawing
        rl.beginDrawing();
        // play music
        rl.updateMusicStream(veridis_quo);
        // Set background
        rl.clearBackground(background);
        // draw
        switch(menu_state) {
            .main_menu => {
                main_menu.draw();
            },
            .game => {
                draw(map, minimap, info_box, button_box, event_log, player, player_tileset);
                if (heatmap_on and !playing_level) {
                    if (mouse_idx > 0) {
                        var d_map = try Algorithm.Pathing.get_dijkstra_map(map, tile_ps, mouse_idx, traversal_type, mobility_type, allocator);
                        d_map.set_font(font);
                        d_map.draw();
                    }
                }
            },
        }
        // input
        // TODO: change playing state to enum
        if (!set_player_position and playing_level == true) {
            player.set_location(.{ .x = -1, .y = -1});
            playing_level = false;
        }
        const m_cursor = rl.getMousePosition();
        for (map.tiles, 0..) |*tile, idx| {
            // Check if the mouse is over the "button" rectangle
            if (rl.checkCollisionPointRec(m_cursor, tile.dest_rect)) {
                mouse_idx = @intCast(idx);
                // Check if the left mouse button was pressed in this specific frame
                if (rl.isMouseButtonPressed(.left)) {
                    // Perform button action here
                    if (tile.get_traversible() == .walk and set_player_position and !playing_level) {
                        player.set_location(.{
                            .x = @as(f32, @floatFromInt(@mod(mouse_idx, map_tw - 2 * map_padding_x_ts))),
                            .y = @as(f32, @floatFromInt(@divFloor(mouse_idx, map_tw - 2 * map_padding_x_ts))),
                        });
                        playing_level = true;
                        std.debug.print("location set: {}", .{player.location});
                    }
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
        if (rl.checkCollisionPointRec(m_cursor, button_box.rect)) {
            if (rl.isMouseButtonPressed(.left)) {
                button_box.on_click(m_cursor);
            }
        }
        switch (menu_state) {
            .main_menu => {
                main_menu.handle_input();
            },
            .game => {
                //handle_input();
            },
        }

        switch (rl.getKeyPressed()) {
            .escape => {
                menu_state = .main_menu;
            },
            .f11 => {
                if (rl.isWindowState(.{.window_undecorated = true})) {
                    rl.clearWindowState(.{.window_undecorated = true});
                } else {
                    rl.setWindowState(.{.window_undecorated = true});
                }
            },
            .kp_1 => {
                player.move(traversal_type, .south_west, map);
            },
            .kp_2 => {
                player.move(traversal_type, .south, map);
            },
            .kp_3 => {
                player.move(traversal_type, .south_east, map);
            },
            .kp_4 => {
                player.move(traversal_type, .west, map);
            },
            .kp_6 => {
                player.move(traversal_type, .east, map);
            },
            .kp_7 => {
                player.move(traversal_type, .north_west, map);
            },
            .kp_8 => {
                player.move(traversal_type, .north, map);
            },
            .kp_9 => {
                player.move(traversal_type, .north_east, map);
            },
            else => {
                // do nothing
            },
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

fn draw(map: Grid, minimap: MiniMap, info_box: ButtonBox, button_box: ButtonBox, event_log: EventLog, player: Actor, actor_tileset: rl.Texture2D) void {
    
    map.draw();
    minimap.draw();
    const map_canvas = map.get_canvas();
    //const minimap_canvas = minimap.get_canvas();
    draw_entities(
        map_canvas,
        //minimap_canvas,
        map.tile_ps,
        map.tile_ps,
        map.width,
        map.height,
        player,
        actor_tileset
    );


    info_box.draw();
    button_box.draw();
    event_log.draw();
}

fn draw_entities(map_canvas: rl.Rectangle, tile_pw: f32, tile_ph: f32,  map_tw: u32, map_th: u32, player: Actor, entity_tileset: rl.Texture2D) void {
    const p_location = player.get_location();
    for (0..map_th) |y| {
        for (0..map_tw) |x| {
            const dest = rl.Vector2{
                .x = @as(f32, @floatFromInt(x)) * tile_pw + map_canvas.x,
                .y = @as(f32, @floatFromInt(y)) * tile_ph + map_canvas.y,
            };
            if (@abs(p_location.x - @as(f32, @floatFromInt(x))) <= 0.001
                and @abs(p_location.y - @as(f32, @floatFromInt(y))) <= 0.001) {
                draw_texture(.{
                        .x = 0,
                        .y = 0,
                        .width = tile_pw,
                        .height = tile_ph,
                    }, 
                    dest,
                    entity_tileset
                );
            }
        }
    }
}

fn draw_texture(src: rl.Rectangle, dest: rl.Vector2, tile_set: rl.Texture2D) void {
    rl.drawTextureRec(tile_set, src, dest, .white);
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

