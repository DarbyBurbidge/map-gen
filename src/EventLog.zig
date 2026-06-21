const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const rl = @import("raylib");
const rg = @import("raygui");
const Rectangle = rl.Rectangle;
const Font = rl.Font;
const Vector2 = rl.Vector2;
const Texture2D = rl.Texture2D;
const fade = rl.fade;
const measureTextEx = rl.measureTextEx;

const EventMessage = @import("EventMessage.zig");
const TextHighlight = EventMessage.TextHighlight;
const MessageType = EventMessage.MessageType;

pub const Config = struct {
    rect: Rectangle,
    font: Font,
    tile_ps: f32,
    border_tileset: Texture2D,
};

const roundness: f32 = 0.0;
const segments: f32 = 0.0;
const spacing: i32 = 0;

// Shimmer settings
const speed = 5.0;       // How fast the wave moves
const frequency = 0.5;   // Spacing between wave peaks
const amplitude = 15.0;  // How bright the shimmer gets

io: Io,
allocator: Allocator,
rect: Rectangle,
font: Font,
tile_ps: f32,
border_tileset: Texture2D,
events: ArrayList(EventMessage),

pub fn init(config: Config, io: Io, allocator: Allocator) @This() {
    return @This(){
        .io = io,
        .allocator = allocator,
        .rect = config.rect,
        .font = config.font,
        .tile_ps = config.tile_ps,
        .border_tileset = config.border_tileset,
        .events = .empty,
    };
}

pub fn draw(self: @This()) void {
    rl.drawRectangleRounded(self.rect, roundness, @as(i32, @intFromFloat(segments)), .fade(.black, 1.0));
    // draw border tiles
    self.draw_border();
    // draw text
    var y_off: i32 = 24;
    for (self.events.items) |u_item| {
        self.draw_text(u_item, @floatFromInt(y_off));
        y_off += 16;
    }
}

fn draw_text(self: @This(), message: EventMessage, y_off: f32) void {
    var x_off: f32 = 16;
    var hl_idx: u32 = 0;
    var alpha: f32 = 1.0;
    if (y_off > 0.3 * self.rect.height) {
        alpha = 1 - (y_off - 0.3 * self.rect.height) / self.rect.height;
    }
    for (message.text) |u_char| {
        if (y_off > self.rect.height - 16) {
            return;
        }
        const charSize = measureTextEx(self.font, &.{u_char, '0'}, 16.0, -2);
        const pos = Vector2{.x = self.rect.x + x_off, .y = self.rect.y + self.rect.height - y_off};
        if (u_char == '{' and hl_idx < message.hl_text.len) {
            x_off += self.draw_hl_text(message.hl_text[hl_idx], pos, alpha); 
            hl_idx += 1;
            continue;
        } else if (u_char == '}') {
            continue;
        }

        self.draw_char(u_char, pos, message.type.get_color().fade(alpha));
        x_off += charSize.x - 2;
    }
}

fn draw_hl_text(self: @This(), hl_text: TextHighlight, msg_pos: Vector2, alpha: f32) f32 {
    const timestamp: Io.Timestamp = .now(self.io, .awake);
    const base_color = hl_text.get_color1();
    const secondary_color = hl_text.get_color2();
    const effect  = hl_text.get_effect();
    var x_off: f32 = 0;
    for (hl_text.text, 0..) |u_char, i| {
        const charSize = measureTextEx(self.font, &.{u_char, '0'}, 12.0, spacing);
        const pos = Vector2{.x = msg_pos.x + x_off, .y = msg_pos.y};
        switch (effect) {
            .flat => {
                self.draw_char(u_char, pos, base_color.fade(alpha));
            },
            .shimmer => {
                // calculate alpha for secondary color
                const new_alpha: f32 = std.math.sin(@as(f32, @floatFromInt(@divFloor(timestamp.toMilliseconds(), 100))) + 
@as(f32, @floatFromInt(i)) * 90) / 2 + 0.5;

                // draw with alpha
                self.draw_char(u_char, pos, base_color.fade(alpha));
                self.draw_char(u_char, pos, secondary_color.fade(new_alpha * alpha));
            },
            .fading => {
                // calculate alpha for secondary color
                const new_alpha: f32 = std.math.sin(@as(f32, @floatFromInt(@divFloor(timestamp.toMilliseconds(), 200)))) / 4 + 0.75;

                // draw with alpha
                self.draw_char(u_char, pos, base_color.fade(new_alpha * alpha));
            },
        }
        x_off += charSize.x;
    }
    return x_off;

}

fn draw_char(self: @This(), char: u8, pos: Vector2, color: rl.Color) void {
    rl.drawTextEx(self.font, &.{char}, pos, 16.0, 0, color);
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

pub fn log(self: *@This(), text: []const u8, m_type: MessageType, hl_texts: []const TextHighlight) void {
    const event = EventMessage{
        .text = text,
        .type = m_type,
        .hl_text = hl_texts,
    };
    self.events.insert(self.allocator, 0, event) catch |err| {
        std.debug.print("Error Logging {any}\n", .{err});
    };
}
