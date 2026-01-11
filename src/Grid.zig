const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const Rectangle = rl.Rectangle;
const Tile = @import("Tile.zig");
const Traversible = Tile.Traversible;
const Self = @This();

allocator: *const Allocator,
width: u16,
height: u16,
tiles: []Tile,

pub fn init(screenWidth: u16, screenHeight: u16, tileSize: u8, gpa: *const Allocator) !Self {
    assert(screenWidth % tileSize == 0);
    assert(screenHeight % tileSize == 0);
    const gridWidth = screenWidth / tileSize;
    const gridHeight = screenHeight / tileSize;
    const gridSize = gridWidth * gridHeight;
    var tiles = try gpa.alloc(Tile, gridSize);
    for (0..gridSize) |idx| {
        const x_pos = (idx % gridWidth) * tileSize;
        const y_pos = (idx / gridWidth) * tileSize;
        tiles[idx] = Tile.init(@floatFromInt(x_pos), @floatFromInt(y_pos), @floatFromInt(tileSize), .unformed);
    }

    return Self{
        .allocator = gpa,
        .width = gridWidth,
        .height = gridHeight,
        .tiles = tiles,
    };
}
