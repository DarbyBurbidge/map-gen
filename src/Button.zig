const std = @import("std");
const rl = @import("raylib");
const Pathing = @import("Algorithm.zig").Pathing;
const PathingAlgo = Pathing.Algorithm;
const Mobility = Pathing.Mobility;

const Active = enum {
    on,
    off,
};

rect: rl.Rectangle,
message: [:0]const u8,
color: rl.Color,

const TraversalType = @import("Tile.zig").TraversalType;

pub const ButtonBox = struct {
    rect: rl.Rectangle,
    inner_rect: rl.Rectangle,
    color: rl.Color,
    border_color: rl.Color,
};

pub const ResetButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font) @This() {
        return ResetButton{
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = "reset"[0..],
            .color = .red,
            .text_color = .dark_gray,
            .font = font,
        };
    }

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
};

pub const TraversalButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,
    active: Active,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font) @This() {
        return TraversalButton{
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = "walking"[0..],
            .color = .light_gray,
            .text_color = .dark_gray,
            .font = font,
            .active = .off,
        };
    }

    pub fn on_click(self: *@This(), traversal_type: *TraversalType) void {
        if (self.active == .on) {
            self.active = .off;
            self.message = "walking"[0..];
            self.color = .light_gray;
            self.text_color = .dark_gray;
            traversal_type.* = .walk;
        } else {
            self.active = .on;
            self.message = "flying"[0..];
            self.color = .dark_gray;
            self.text_color = .gold;
            traversal_type.* = .fly;
        }
    }

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 0, self.text_color);
    }
};

pub const PathingButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font, algo: PathingAlgo) @This() {
        var message: [:0]const u8 = undefined;
        var color: rl.Color = undefined;
        var text_color: rl.Color = undefined;
        switch (algo) {
            .dfs => {
                message = "dfs"[0..];
                color = .light_gray;
                text_color = .dark_gray;
            },
            .bfs => {
                message = "bfs"[0..];
                color = .dark_gray;
                text_color = .gold;
            },
            .dijkstra => {
                message = "dijkstra"[0..];
                color = .dark_gray;
                text_color = .light_gray;
            },
            .a_star => {
                message = "a star"[0..];
                color = .dark_gray;
                text_color = .gold;
            },
        }
        return PathingButton{
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = message,
            .color = color,
            .text_color = text_color,
            .font = font,
        };
    }

    pub fn on_click(self: *@This(), algo: *PathingAlgo) void {
        algo.next();
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

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
};

pub const MapAlgorithmButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font) @This() {
        return @This(){
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = "cellular"[0..],
            .color = .light_gray,
            .text_color = .dark_gray,
            .font = font,
        };
    }

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
};

pub const MapGenButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font) @This() {
        return @This(){
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = "create!"[0..],
            .color = .green,
            .text_color = .dark_gray,
            .font = font,
        };
    }

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
};

pub const HeatMapButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font) @This() {
        return @This(){
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = "heatmap"[0..],
            .color = .orange,
            .text_color = .dark_gray,
            .font = font,
        };
    }

    pub fn on_click(toggle: bool) bool {
        return !toggle;
    }

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
};
pub const PathMobilityButton = struct {
    border_box: rl.Rectangle,
    body: rl.Rectangle,
    message: [:0]const u8,
    color: rl.Color,
    text_color: rl.Color,
    font: rl.Font,

    pub fn init(x: f32, y: f32, width: f32, height: f32, font: rl.Font) @This() {
        return @This(){
            .border_box = rl.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .body = rl.Rectangle{
                .x = x + 2,
                .y = y + 2,
                .width = width - 4,
                .height = height - 4,
            },
            .message = "ortho"[0..],
            .color = .light_gray,
            .text_color = .dark_gray,
            .font = font,
        };
    }

    pub fn on_click(self: *@This(), mobility_type: *Mobility) void {
        mobility_type.next();
        switch (mobility_type.*) {
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

    pub fn draw(self: *@This()) void {
        rl.drawRectangleRounded(self.border_box, 0.2, @as(i32, @intFromFloat(0.0)), .fade(.black, 1.0));
        rl.drawRectangleRounded(self.body, 0.2, @as(i32, @intFromFloat(0.0)), .fade(self.color, 1.0));
        rl.drawTextEx(self.font, self.message[0.. :0], .{ .x = self.body.x + 12, .y = self.body.y + 2 }, @floatFromInt(self.font.baseSize), 2, self.text_color);
    }
};
