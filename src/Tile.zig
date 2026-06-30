const std = @import("std");
const Io = std.Io;
const rl = @import("raylib");
const Tag = std.meta.Tag;
const Rectangle = rl.Rectangle;
const Texture2D = rl.Texture2D;
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

pub const MapType = enum {
    local,
    region,
    overworld,
};

const OverType = enum {
    deep_sea,
    ocean,
    coastal,
    beach,
    grassland,
    forest,
    mountain,
    summit,
};

pub const Biome = enum(u8) {
    dungeon,
    cave,
};

pub const Type = enum(u8) {
    wall,
    ceiling,
    floor,
    open,
    abyss,
    unformed,
};

const BiomeType = packed struct {
    biome: Biome,
    type: Type,
};

io: Io,
over_type: OverType,
biome: Biome,
type: Type,
src_rect: Rectangle,
dest_rect: Rectangle,
tileset: Texture2D,
border: f32,
state: TileState,
custom_color: rl.Color,

pub fn init(x: f32, y: f32, size: f32, tileset: Texture2D, comptime biome: Biome, comptime tile_type: Type, io: Io) @This() {
    return @This(){
        .io = io,
        .over_type = .deep_sea,
        .biome = biome,
        .type = tile_type,
        .src_rect = rl.Rectangle{
            .x = size * 3,
            .y = 0,
            .width = size,
            .height = size,
        },
        .dest_rect = rl.Rectangle{
            .x = x,
            .y = y,
            .width = size,
            .height = size,
        },
        .tileset = tileset,
        .border = 0,
        .state = .none,
        .custom_color = .dark_gray,
    };
}

pub fn get_traversible(self: @This()) Traversible {
    return switch (self.type) {
        .ceiling => .no,
        .wall, .floor => .walk,
        .open, .abyss => .fly,
        .unformed => .no,
    };
}

pub fn get_color(self: @This()) rl.Color {
    return switch (self.state) {
        .start => .green,
        .end => .red,
        .traversed => .yellow,
        .none => switch (self.type) {
            .wall => .brown,
            .ceiling => .dark_gray,
            .floor => .brown,
            .open => .black,
            .abyss => .black,
            .unformed => .dark_gray,
        },
    };
}

pub fn set_state(self: *@This(), state: TileState) void {
    self.state = state;
}

pub fn set_biome(self: *@This(), biome: Biome) void {
    self.biome = biome;
}

pub fn get_type(self: @This()) Type {
    return self.type;
}

pub fn set_localtype(self: *@This(), type_enum: Type) void {
    self.type = type_enum;
    self.set_texture(.local);
}

pub fn set_overtype(self: *@This(), type_enum: OverType) void {
    self.over_type = type_enum;
    self.set_texture(.overworld);
}

pub fn set_texture(self: *@This(), map_type: MapType) void {
    switch (map_type) {
        .local => {
            self.set_local_texture();
        },
        .region => {
            self.set_region_texture();
        },
        .overworld => {
            self.set_overworld_texture();
        },
    }
}

fn set_overworld_texture(self: *@This()) void {
    var src = Rectangle{
        .x = -1,
        .y = -1,
        .width = self.src_rect.width,
        .height = self.src_rect.height,
    };
    switch (self.over_type) {
        .deep_sea => {
            src.x = 0;
            src.y = self.src_rect.height * 4;
        },
        .ocean => {
            src.x = self.src_rect.width * 1;
            src.y = self.src_rect.height * 4;
        },
        .coastal => {
            src.x = self.src_rect.width * 2;
            src.y = self.src_rect.height * 4;
        },
        .beach => {
            src.x = self.src_rect.width * 3;
            src.y = self.src_rect.height * 4;
        },
        .grassland => {
            src.x = self.src_rect.width * 3;
            src.y = self.src_rect.height * 5;
        },
        .forest => {
            src.x = 0;
            src.y = self.src_rect.height * 5;
        },
        .mountain => {
            src.x = self.src_rect.width;
            src.y = self.src_rect.height * 5;
        },
        .summit => {
            src.x = self.src_rect.width * 2;
            src.y = self.src_rect.height * 5;
        },
    }
    self.src_rect = src;
}

pub fn set_region_texture(self: *@This()) void {
    _ = self;
    return;
}

pub fn set_local_texture(self: *@This()) void {
    const rng_impl: std.Random.IoSource = .{ .io = self.io };
    const rand = rng_impl.interface();
    var src = Rectangle{
        .x = -1,
        .y = -1,
        .width = self.src_rect.width,
        .height = self.src_rect.height,
    };
    switch (BiomeType{.biome = self.biome, .type = self.type}) {
        .{ .biome = .dungeon, .type = .wall } => {
            src.x = self.src_rect.width * 4;
            src.y = 0;
        },
        .{ .biome = .dungeon, .type = .floor } => {
            const r_val = rand.float(f32);
            src.y = 0;
            if (r_val < 0.7) {
                src.x = 0;
            } else if (r_val < 0.85) {
                src.x = self.src_rect.width;
            } else {
                src.x = self.src_rect.width * 2;
            }
        },
        .{ .biome = .cave, .type = .wall } => {
            src.x = self.src_rect.width * @as(
                f32, @floatFromInt(rand.intRangeAtMost(u32, 0, 5))
            );
            src.y = self.src_rect.height;
        },
        .{ .biome = .cave, .type = .floor } => {
            src.x = self.src_rect.width * @as(
                f32, @floatFromInt(rand.intRangeAtMost(u32, 0, 5))
            );
            src.y = self.src_rect.height * 2;
        },
        .{ .biome = .cave, .type = .open }, .{ .biome = .dungeon, .type = .open } => {
            src.x = self.src_rect.width * @as(
                f32, @floatFromInt(rand.intRangeAtMost(u32, 0,3))
            );
            src.y = self.src_rect.height * 3;
        },
        .{ .biome = .cave, .type = .abyss }, .{ .biome = .dungeon, .type = .abyss } => {
            src.x = self.src_rect.width * 4;
            src.y = self.src_rect.height * 3;
        },
        .{ .biome = .dungeon, .type = .ceiling }, .{ .biome = .cave, .type = .ceiling } => {
            src.x = self.src_rect.width * 5;
            src.y = 0;
        },
        .{ .biome = .dungeon, .type = .unformed }, .{ .biome = .cave, .type = .unformed } => {
            src.x = self.src_rect.width * 3;
            src.y = 0;
        },
        else => unreachable,
    }
    self.src_rect = src;
}

pub fn set_custom_color(self: *@This(), color: rl.Color) void {
   self.custom_color = color; 
}


pub fn draw(self: @This()) void {
    rl.drawTextureRec(self.tileset, self.src_rect, .{.x = self.dest_rect.x, .y = self.dest_rect.y}, .white);
}

pub fn draw_custom(self: @This()) void {
    const rect = self.dest_rect;
    rl.drawRectangleRounded(rect, 0.0, 0, .fade(self.custom_color, 1.0));
}

pub fn clear(self: *@This()) void {
        self.set_biome(.cave);
        self.set_localtype(.unformed);
        self.custom_color = .dark_gray;
}
