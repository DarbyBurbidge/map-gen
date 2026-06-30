const std = @import("std");
const rl = @import("raylib");

const Health = @import("Health.zig");
const Inventory = @import("Inventory.zig");
const Grid = @import("Grid.zig");
const Mobility = @import("Algorithm.zig").Pathing.Mobility;
const TraversalType = @import("Tile.zig").TraversalType;

const Direction = enum {
    south_west,
    south,
    south_east,
    west,
    east,
    north_west,
    north,
    north_east,
};

name: [:0]const u8,
hp: Health,
//inventory: Inventory,
location: rl.Vector2,
tileset: rl.Texture2D,

pub fn get_location(self: @This()) rl.Vector2 {
    return self.location;
}

pub fn set_location(self: *@This(), location: rl.Vector2) void {
    self.location = location;
}

pub fn move(self: *@This(), traversal_type: TraversalType, direction: Direction, map: Grid) void {
    var new_location = self.location;
    switch (direction) {
        .south_west => {
            new_location.x -= 1;
            new_location.y += 1;
        },
        .south => {
            new_location.y += 1;
        },
        .south_east => {
            new_location.x += 1;
            new_location.y += 1;
        },
        .west => {
            new_location.x -= 1;
        },
        .east => {
            new_location.x += 1;
        },
        .north_west => {
            new_location.x -= 1;
            new_location.y -= 1;
        },
        .north => {
            new_location.y -= 1;
        },
        .north_east => {
            new_location.x += 1;
            new_location.y -= 1;
        },
    }
    if (map.is_traversible(traversal_type, new_location)) {
        self.location = new_location;
    }
}
