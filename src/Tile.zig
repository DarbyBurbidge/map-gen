const std = @import("std");
const rl = @import("raylib");
const Tag = std.meta.Tag;
const Rectangle = rl.Rectangle;
const Color = rl.Color;

pub const Traversible = enum {
    no,
    walk,
    fly,
};

pub const TraversalType = enum {
    walk,
    fly,
};

const TileState = enum {
    none,
    start,
    end,
    traversed,
};

const TileType = union(enum) {
    wall,
    floor,
    open,
    unformed,
};

type: TileType,
rect: Rectangle,
border: f32,
state: TileState,

pub fn init(x: f32, y: f32, size: f32, comptime tile_type: Tag(TileType)) @This() {
    return @This(){
        .type = tile_type,
        .rect = rl.Rectangle{
            .x = x,
            .y = y,
            .width = size,
            .height = size,
        },
        .border = 2,
        .state = .none,
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
            .unformed => .white,
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

pub fn draw(self: @This()) void {
    const rect = self.rect;
    const inner_rect = Rectangle{
        .x = rect.x + self.border,
        .y = rect.y + self.border,
        .width = rect.width - (self.border * 2),
        .height = rect.height - (self.border * 2),
    };

    rl.drawRectangleRounded(rect, 0.2, 0, .fade(.black, 1.0));
    rl.drawRectangleRounded(inner_rect, 0.2, 0, .fade(self.get_color(), 1.0));
}
