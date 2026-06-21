const std = @import("std");
const rl = @import("raylib");
const Tag = std.meta.Tag;
const Rectangle = rl.Rectangle;
const Color = rl.Color;

const EventLog = @import("EventLog.zig");

pub const Traversible = enum {
    no,
    walk,
    fly,
};

pub const TraversalType = enum {
    walk,
    fly,

    pub fn next(self: *@This(), logger: *EventLog) void {
        switch (self.*) {
            .fly => {
                self.* = .walk;
                logger.log(
                    "You feel yourself sink slowly back to the ground.", 
                    .warning, 
                    &.{}
                );
            },
            .walk => {
                self.* = .fly;
                logger.log(
                    "You feel youself float into the air!",
                    .warning,
                    &.{}
                );
            },
        }
    }
};

const TileState = enum {
    none,
    start,
    end,
    traversed,
};

pub const TileType = union(enum) {
    wall,
    floor,
    open,
    unformed,
};

type: TileType,
rect: Rectangle,
border: f32,
state: TileState,
custom_color: rl.Color,

pub fn init(x: f32, y: f32, size: f32, comptime tile_type: Tag(TileType)) @This() {
    return @This(){
        .type = tile_type,
        .rect = rl.Rectangle{
            .x = x,
            .y = y,
            .width = size,
            .height = size,
        },
        .border = 0,
        .state = .none,
        .custom_color = .dark_gray,
    };
}

pub fn get_traversible(self: @This()) Traversible {
    return switch (self.type) {
        .wall => .no,
        .floor => .walk,
        .open => .fly,
        .unformed => .no,
    };
}

pub fn get_color(self: @This()) rl.Color {
    return switch (self.state) {
        .start => .green,
        .end => .red,
        .traversed => .yellow,
        .none => switch (self.type) {
            .wall => .gray,
            .floor => .brown,
            .open => .black,
            .unformed => .dark_gray,
        },
    };
}

pub fn set_state(self: *@This(), state: TileState) void {
    self.state = state;
}

pub fn set_type(self: *@This(), type_enum: TileType) void {
    switch (type_enum) {
        .wall => {
            self.type = .wall;
        },
        .floor => {
            self.type = .floor;
        },
        .open => {
            self.type = .open;
        },
        .unformed => {
            self.type = .unformed;
        },
    }
}
pub fn set_custom_color(self: *@This(), color: rl.Color) void {
   self.custom_color = color; 
}


pub fn draw(self: @This()) void {
    const rect = self.rect;
    const inner_rect = Rectangle{
        .x = rect.x + self.border,
        .y = rect.y + self.border,
        .width = rect.width - (self.border * 2),
        .height = rect.height - (self.border * 2),
    };

    rl.drawRectangleRounded(rect, 0.0, 0, .fade(.black, 1.0));
    rl.drawRectangleRounded(inner_rect, 0.0, 0, .fade(self.get_color(), 1.0));
}

pub fn draw_custom(self: @This()) void {
    const rect = self.rect;
    const inner_rect = Rectangle{
        .x = rect.x + self.border,
        .y = rect.y + self.border,
        .width = rect.width - (self.border * 2),
        .height = rect.height - (self.border * 2),
    };

    rl.drawRectangleRounded(rect, 0.0, 0, .fade(.black, 1.0));
    rl.drawRectangleRounded(inner_rect, 0.0, 0, .fade(self.custom_color, 1.0));
}

pub fn clear(self: *@This()) void {
        self.type = .unformed;
        self.custom_color = .dark_gray;
}
