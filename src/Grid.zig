const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const Rectangle = rl.Rectangle;
const Tile = @import("Tile.zig");
const Traversible = Tile.Traversible;
const Self = @This();
const TileType = Tile.TileType;

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

    std.debug.print("gridSize: {}", .{gridSize});
    return Self{
        .allocator = gpa,
        .width = gridWidth,
        .height = gridHeight,
        .tiles = tiles,
    };

}

pub fn clear(self: *const @This()) void {
    const gridSize = self.width * self.height;
    for (0..gridSize) |idx| {
        self.tiles[idx].set_type(.unformed);
        self.tiles[idx].voronoi_color = .white;
    }
}

pub fn fill(self: *const @This(), fill_type: TileType) void {
    const gridSize = self.width * self.height;
    for (0..gridSize) |idx| {
        self.tiles[idx].set_type(fill_type);
    }
}

pub fn fix_edges(self: *const @This()) void {
    const gridSize = self.width * self.height;
    for (0..gridSize) |idx| {
        if (idx % self.width == 0 or idx % self.width == self.width - 1 or idx < self.width or idx >= self.width * (self.height - 1)) {
            self.tiles[idx].set_type(.wall);
        }
    }
}
