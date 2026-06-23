const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const rl = @import("raylib");
const Rectangle = rl.Rectangle;
const Vector2 = rl.Vector2;
const Texture2D = rl.Texture2D;
const Tile = @import("Tile.zig");
const Traversible = Tile.Traversible;
const Self = @This();
const TileType = Tile.Type;

pub const Config = struct{
    rect: Rectangle,
    tile_ps: f32,
    border_tileset: Texture2D,
    padding_tileset: Texture2D,
    tile_tileset: Texture2D,
    padding_x: u16,
    padding_y: u16,
    tw: u16,
    th: u16,
};

const PaddingTile = struct{
    src: Rectangle,
    dest: Vector2,
};

io: Io,
allocator: Allocator,
rect: Rectangle,
tile_ps: f32,
border_tileset: Texture2D,
padding_tileset: Texture2D,
padding_x: u16,
padding_y: u16,
width: u16,
height: u16,
tiles: []Tile,
padding_tiles: std.ArrayList(PaddingTile),

pub fn init(config: Config, io: Io, gpa: Allocator) !Self {
    const num_tiles = config.tw * config.th;
    var tiles = try gpa.alloc(Tile, num_tiles);
    for (0..num_tiles) |idx| {
        const x_pos = @as(f32, @floatFromInt((idx % config.tw) + config.padding_x)) * config.tile_ps;
        const y_pos = @as(f32, @floatFromInt((idx / config.tw) + config.padding_y)) * config.tile_ps;
        tiles[idx] = Tile.init(
            x_pos,
            y_pos,
            config.tile_ps, 
            config.tile_tileset,
            .cave,
            .unformed,
            io,
        );
    }

    const max_width = config.tw + 2 * config.padding_x;
    const max_height = config.th + 2 * config.padding_y;
    const padding_tiles = try generate_padding(config.rect, max_width, max_height, config.padding_x, config.padding_y, config.tile_ps, io, gpa);

    std.debug.print("gridWidth: {d}, gridHeight: {d}, gridSize: {d}", .{config.tw, config.th, num_tiles});
    return Self{
        .io = io,
        .allocator = gpa,
        .rect = config.rect,
        .tile_ps = config.tile_ps,
        .padding_x = config.padding_x,
        .padding_y = config.padding_y,
        .width = config.tw,
        .height = config.th,
        .border_tileset = config.border_tileset,
        .padding_tileset = config.padding_tileset,
        .tiles = tiles,
        .padding_tiles = padding_tiles,
    };

}

pub fn clear(self: *const @This()) void {
    const gridSize = self.width * self.height;
    for (0..gridSize) |idx| {
        self.tiles[idx].clear();
    }
}

pub fn fill(self: *const @This(), fill_type: TileType) void {
    const gridSize = self.width * self.height;
    for (0..gridSize) |idx| {
        self.tiles[idx].set_localtype(fill_type);
    }
}

pub fn fix_edges(self: *const @This()) void {
    const gridSize = self.width * self.height;
    for (0..gridSize) |idx| {
        if (
            idx % self.width == 0 or
            idx % self.width == self.width - 1 or
            idx < self.width or
            idx >= self.width * (self.height - 1)
        ) {
            self.tiles[idx].set_localtype(.ceiling);
        }
        if (idx > self.width and
            self.tiles[idx].get_type() == .floor and
            self.tiles[idx - self.width].get_type() == .ceiling
        ) {
            self.tiles[idx].set_localtype(.wall);
        }
        if (idx > self.width and
            self.tiles[idx].get_type() == .open and
            (self.tiles[idx - self.width].get_type() == .open or
            self.tiles[idx - self.width].get_type() == .abyss)
        ) {
            self.tiles[idx].set_localtype(.abyss);
        }
    }
}

pub fn draw(self: *const @This()) void {
    // draw background
    rl.drawRectangleRounded(.{.x = self.rect.x, .y = self.rect.y, .width = self.rect.width, .height = self.rect.height}, 0, @as(i32, @intFromFloat(0.0)), .fade(.dark_gray, 1.0));
    // draw tiles
    for (self.tiles) |tile| {
        tile.draw();
    }

    // draw padding
    self.draw_padding();

    // draw border
    self.draw_border();

}

pub fn draw_custom(self: *const @This()) void {
    for (self.tiles) |tile| {
        tile.draw_custom();
    }
    
    // draw padding
    self.draw_padding();

    // draw border
    self.draw_border();
}

fn generate_padding(panel: Rectangle, max_width: u32, max_height: u32, padding_x: u16, padding_y: u16, tile_ps: f32, io: Io, allocator: Allocator) !std.ArrayList(PaddingTile) {
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rand = rng_impl.interface();
    var padding_tiles: std.ArrayList(PaddingTile) = .empty;
    // which side of brick does the row start on.
    // left is false
    var brick_parity: u32 = 0;
    for (0..max_height) |y| {
        for (0..max_width) |x| {
            var src = Rectangle{
                .x = 0,
                .y = 0,
                .width = tile_ps,
                .height = tile_ps,
            };
            // draw overhang tiles
            if ((
                y >= padding_y and
                y <= max_height - 1 - padding_y
            ) and (
                x == padding_x or 
                x == max_width - 1 - padding_x
            ) and ((
                    max_width % 2 == padding_y % 2 and 
                    y % 2 == 0
                ) or (
                    max_width % 2 != padding_y % 2 and 
                    y % 2 == 1
            ))) {
                if (brick_parity % 2 == 0) {
                    src.x = @as(f32, @floatFromInt(
                        rand.intRangeAtMost(u32, 0, 1) * 2
                    )) * tile_ps;
                } else {
                    src.x = @as(f32, @floatFromInt(
                        rand.intRangeAtMost(u32, 0, 1) * 2 + 1
                    )) * tile_ps;
                }
                src.y = 2 * tile_ps;
                const dest = Vector2{
                    .x = @as(f32, @floatFromInt(x)) * tile_ps + panel.x,
                    .y = @as(f32, @floatFromInt(y)) * tile_ps + panel.y,
                };
                try padding_tiles.append(allocator, PaddingTile{
                    .dest = dest,
                    .src = src,
                });
            }
            // draw full tiles
            if ((
                y < padding_y or 
                y > max_height - 1 - padding_y
            ) or (
                x < padding_x or
                x > max_width - 1 - padding_x
            )) {
                // get next brick
                if (brick_parity % 2 == 0) {
                    src.x = @as(f32, @floatFromInt(
                        rand.intRangeAtMost(u32, 0, 1) * 2
                    )) * tile_ps;
                } else {
                    src.x = @as(f32, @floatFromInt(
                        rand.intRangeAtMost(u32, 0, 1) * 2 + 1
                    )) * tile_ps;
                }
                src.y = @as(f32, @floatFromInt(
                    rand.intRangeAtMost(u32, 0, 1)
                )) * tile_ps;
                const dest = Vector2{
                    .x = @as(f32, @floatFromInt(x)) * tile_ps + panel.x,
                    .y = @as(f32, @floatFromInt(y)) * tile_ps + panel.y,
                };
                try padding_tiles.append(allocator, PaddingTile{
                    .dest = dest,
                    .src = src,
                });
            }
            brick_parity += 1;
        }
        brick_parity += 1;
    }
    return padding_tiles;
}

fn draw_padding(self: @This()) void {
    // which side of brick does the row start on.
    // left is false
    for (self.padding_tiles.items) |u_tile| {
        rl.drawTextureRec(self.padding_tileset, u_tile.src, u_tile.dest, .white);
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
