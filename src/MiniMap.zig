const std = @import("std");
const rl = @import("raylib");
const Rectangle = rl.Rectangle;
const Texture2D = rl.Texture2D;
const Vector2 = rl.Vector2;
const Color = rl.Color;

const Tile = @import("Tile.zig");

pub const Config = struct {
    tiles: []Tile,
    tile_ps: f32,
    map_width: u16,
    rect: Rectangle,
    color: Color,
    border_tileset: Texture2D,
};

tiles: []Tile,
tile_ps: f32,
map_width: u16,
rect: Rectangle,
color: Color,
border_tileset: Texture2D,

pub fn init(config: Config) @This() {
    return @This(){
        .tiles = config.tiles,
        .tile_ps = config.tile_ps,
        .map_width = config.map_width,
        .rect = config.rect,
        .color = config.color,
        .border_tileset = config.border_tileset,
    };
}

pub fn draw(self: *const @This()) void {
    // background
    rl.drawRectangleRounded(.{.x = self.rect.x, .y = self.rect.y, .width = self.rect.width, .height = self.rect.height}, 0, @as(i32, @intFromFloat(0.0)), self.color);
    // border
    self.draw_border(); 

    // draw tile repr
    for (0..self.tiles.len) |i| {
        //const t_type = u_tile.get_type();
        const t_color = self.tiles[i].get_color();
        
        const x = i % self.map_width;
        const y = i / self.map_width;
        const mm_tw = (self.rect.width - 12) / self.map_width;
        const mm_th = (self.rect.height - 12) / (@as(f32, @floatFromInt(self.tiles.len)) / self.map_width);
        rl.drawRectangleRec(.{
            .x = self.rect.x + 6 + @as(f32, @floatFromInt(x)) * mm_tw, 
            .y = self.rect.y + 6 + @as(f32, @floatFromInt(y)) * mm_th, 
            .width = mm_tw, 
            .height = mm_th,
        }, 
        .fade(t_color, 1.0));
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
