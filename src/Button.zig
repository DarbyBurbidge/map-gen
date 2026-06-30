const std = @import("std");
const rl = @import("raylib");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;
const Pathing = @import("Algorithm.zig").Pathing;
const PathingAlgo = Pathing.Algorithm;
const Mobility = Pathing.Mobility;
const Generation = @import("Algorithm.zig").Generation;
const GenerationAlgo = Generation.Algorithm;
const ResetMapAlgoState = Generation.MapState;

const EventLog = @import("EventLog.zig");

const Active = enum {
    on,
    off,
};

pub const OnClick = enum {
    traversal,
    path_algo,
    map_algo,
    mobility,
    toggle,
    menu,
};

rect: Rectangle,
message: [:0]const u8,
color: rl.Color,

const TraversalType = @import("Tile.zig").TraversalType;

pub const ButtonBox = struct {
    allocator: std.mem.Allocator,
    rect: Rectangle,
    color: rl.Color,
    btn_tw: u16,
    btn_th: u16,
    tile_ps: f32,
    border_tileset: rl.Texture2D,
    btns: std.ArrayList(Button),

    pub fn on_click(self: *@This(), m_cursor: Vector2) void {
        // check bounding for btns
        for (self.btns.items) |*u_btn| {
            if (rl.checkCollisionPointRec(m_cursor, u_btn.rect)) {
                u_btn.on_click(u_btn);
            }
        }

    }

    pub fn add_btn(self: *@This(), config: BtnConfig) !void {
        // finalize config
        const btn = Button.init(config);
        try self.btns.append(self.allocator, btn);
    }

    pub fn draw(self: *const @This()) void {
        // draw background
        rl.drawRectangleRounded(.{.x = self.rect.x, .y = self.rect.y, .width = self.rect.width, .height = self.rect.height}, 0, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));

        // draw border
        self.draw_border();

        for (self.btns.items) |u_btn| {
            u_btn.draw();
        }
    }

    fn draw_border(self: @This()) void {
        const logger_tw: u32 = @as(u32, @intFromFloat(self.rect.width / self.tile_ps));
        const logger_th: u32 = @as(u32, @intFromFloat(self.rect.height / self.tile_ps));
        // draw top,
        for (0..logger_th) |y| {
            for (0..logger_tw) |x| {
                var src = Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = self.tile_ps,
                    .height = self.tile_ps,
                };
                if (y == 0 and x == 0) {
                    // draw top left
                    src.x = self.tile_ps * 2;
                    src.y = self.tile_ps * 2;
                } else if (y == 0 and x == logger_tw - 1) {
                    // draw top right
                    src.x = self.tile_ps;
                    src.y = self.tile_ps * 2;
                } else if (y == logger_th - 1 and x == 0) {
                    // draw bottom left
                    src.x = self.tile_ps * 2;
                    src.y = self.tile_ps;
                } else if (y == logger_th - 1 and x == logger_tw - 1) {
                    // draw bottom right
                    src.x = self.tile_ps;
                    src.y = self.tile_ps;
                } else if (y == 0) {
                    // draw top bar
                    src.x = 0;
                    src.y = self.tile_ps * 2;
                } else if (y == logger_th - 1) {
                    // draw bottom bar
                    src.x = 0;
                    src.y = self.tile_ps;
                } else if (x == 0) {
                    // draw left bar
                    src.x = self.tile_ps * 2;
                    src.y = 0;
                } else if (x == logger_tw - 1) {
                    // draw right bar
                    src.x = self.tile_ps;
                    src.y = 0;
                } else {
                    // draw nothing
                }
                const dest = Vector2{
                    .x = @as(f32, @floatFromInt(x)) * self.tile_ps + self.rect.x,
                    .y = @as(f32, @floatFromInt(y)) * self.tile_ps + self.rect.y,
                };
                rl.drawTextureRec(self.border_tileset, src, dest, .white);
            }
        }
    }
};

const BtnConfig = struct {
    rect: rl.Rectangle,
    tile_ps: f32,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,
    tileset: rl.Texture2D,
    logger: *EventLog, 
    on_click: *const fn (*Button) void,
    state: *anyopaque,
};

pub const Button = struct {
    tile_ps: f32,
    rect: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,
    tileset: rl.Texture2D,
    logger: ?*EventLog,
    on_click: *const fn (*Button) void,
    state: *anyopaque,

    pub fn init(config: BtnConfig) @This() {
        return Button{
            .rect = config.rect,
            .tile_ps = config.tile_ps,
            .message = config.message,
            .color = config.color,
            .text_color = config.text_color,
            .font = config.font,
            .tileset = config.tileset,
            .logger = config.logger,
            .on_click = config.on_click,
            .state = config.state,
        };
    }

    pub fn draw(self: *const @This()) void {
        // background
        rl.drawRectangleRounded(.{.x = self.rect.x + 4, .y = self.rect.y + 4, .width = self.rect.width - 8, .height = self.rect.height - 8}, 0, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        // border
        self.draw_border(); 

        // text
        const sent_str = self.message[0..:0];
        const textSize = rl.measureTextEx(self.font, sent_str, 24.0, 0);
        const x_off = (self.rect.width - textSize.x - 12) / 2;
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.rect.x + x_off, .y = self.rect.y + 12 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
    

    fn draw_border(self: @This()) void {
        const btn_tw: u32 = @as(u32, @intFromFloat(self.rect.width / self.tile_ps));
        const btn_th: u32 = @as(u32, @intFromFloat(self.rect.height / self.tile_ps));
        // draw top,
        for (0..btn_th) |y| {
            for (0..btn_tw) |x| {
                var src = Rectangle{
                    .x = self.tile_ps,
                    .y = self.tile_ps,
                    .width = self.tile_ps,
                    .height = self.tile_ps,
                };
                if (y == 0 and x == 0) {
                    // draw top left
                    src.x = 0;
                    src.y = 0;
                } else if (y == 0 and x == btn_tw - 1) {
                    // draw top right
                    src.x = self.tile_ps * 2;
                    src.y = 0;
                } else if (y == btn_th - 1 and x == 0) {
                    // draw bottom left
                    src.x = 0;
                    src.y = self.tile_ps * 2;
                } else if (y == btn_th - 1 and x == btn_tw - 1) {
                    // draw bottom right
                    src.x = self.tile_ps * 2;
                    src.y = self.tile_ps * 2;
                } else if (y == 0) {
                    // draw top bar
                    src.x = self.tile_ps;
                    src.y = 0;
                } else if (y == btn_th - 1) {
                    // draw bottom bar
                    src.x = self.tile_ps;
                    src.y = self.tile_ps * 2;
                } else if (x == 0) {
                    // draw left bar
                    src.x = 0;
                    src.y = self.tile_ps;
                } else if (x == btn_tw - 1) {
                    // draw right bar
                    src.x = self.tile_ps * 2;
                    src.y = self.tile_ps;
                } else {
                    // draw nothing
                }
                const dest = Vector2{
                    .x = @as(f32, @floatFromInt(x)) * self.tile_ps + self.rect.x,
                    .y = @as(f32, @floatFromInt(y)) * self.tile_ps + self.rect.y,
                };
                rl.drawTextureRec(self.tileset, src, dest, .white);
            }
        }
    }
};

pub fn traversal_on_click(self: *Button) void {
    const traversal_type: *TraversalType = @ptrCast(self.state);
    traversal_type.next(self.logger.?);
    switch (traversal_type.*) {
        .fly => {
            self.message = "flying"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
        },
        .walk => {
            self.message = "walking"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
        },
    }
}

pub fn path_algo_on_click(self: *Button) void {
    const algo: *PathingAlgo = @ptrCast(self.state);
    algo.next(self.logger.?);
    switch (algo.*) {
        .dfs => {
            self.message = "dfs"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
        },
        .bfs => {
            self.message = "bfs"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
        },
        .dijkstra => {
            self.message = "dijkstra"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
        },
        .a_star => {
            self.message = "a star"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
        },
    }
}

pub fn map_algo_on_click(self: *Button) void {
    const map_state: *ResetMapAlgoState = @ptrCast(self.state);
    map_state.algo.next(self.logger.?);
    map_state.reset = true;
    switch (map_state.algo) {
        .ca => {
            self.message = "cellular"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
        },
        .bsp => {
            self.message = "BSP"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
        },
        .voronoi => {
            self.message = "voronoi"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
        },
        .noise => {
            self.message = "perlin"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
        },
    }
}

// should probably be modified to enums
pub fn toggle_on_click(self: *Button) void {
    const toggle: *bool = @ptrCast(self.state);
    toggle.* = !toggle.*;
}

pub fn mobility_on_click(self: *Button) void {
    const mobility: *Mobility = @ptrCast(self.state);
    mobility.next(self.logger.?);
    switch (mobility.*) {
        .orthogonal => {
            self.message = "ortho"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
        },
        .diagonal => {
            self.message = "diag"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
        },
    }
}

