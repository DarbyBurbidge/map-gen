const std = @import("std");
const rl = @import("raylib");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Grid = @import("Grid.zig");
const Tile = @import("Tile.zig");
const TraversalType = Tile.TraversalType;

pub const Generation = struct {
    pub fn c_a(grid: Grid, iterations: u8, allocator: Allocator) !void {
        var seed: u64 = undefined;
        std.crypto.random.bytes(std.mem.asBytes(&seed));
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();
        for (0..grid.width) |x| {
            for (0..grid.height) |y| {
                if (x == 0 or x == grid.width - 1) {
                    grid.tiles[x + y * grid.width].set_type(.wall);
                } else if (y == 0 or y == grid.height - 1) {
                    grid.tiles[x + y * grid.width].set_type(.wall);
                } else {
                    const roll = rand.float(f32);
                    if (roll > 0.65) {
                        grid.tiles[x + y * grid.width].set_type(.wall);
                    } else if (roll > 0.45) {
                        grid.tiles[x + y * grid.width].set_type(.open);
                    } else {
                        grid.tiles[x + y * grid.width].set_type(.floor);
                    }
                }
            }
        }
        var counts: ArrayList(NeighborCounts) = .empty;
        defer counts.deinit(allocator);
        for (0..iterations) |_| {
            for (1..grid.width - 1) |x| {
                for (1..grid.height - 1) |y| {
                    const index = x + y * grid.width;
                    try counts.append(allocator, count_neighbors(grid, index));
                }
            }
            for (1..grid.width - 1) |x| {
                for (1..grid.height - 1) |y| {
                    const index = x + y * grid.width;
                    const count = counts.pop();
                    if (count.?.wall > 4) {
                        grid.tiles[index].set_type(.wall);
                    } else if (count.?.floor == 8) {
                        grid.tiles[index].set_type(.wall);
                    } else if (count.?.open > 3) {
                        grid.tiles[index].set_type(.open);
                    } else {
                        grid.tiles[index].set_type(.floor);
                    }
                }
            }
        }
    }

    pub fn count_neighbors(grid: Grid, index: u64) NeighborCounts {
        var counter: NeighborCounts = .{ .wall = 0, .floor = 0, .open = 0 };
        for (0..3) |x| {
            for (0..3) |y| {
                const neighbor_type = grid.tiles[index - grid.width - 1 + x + y * (grid.width)].type;
                switch (neighbor_type) {
                    .wall => {
                        counter.wall += 1;
                    },
                    .floor => {
                        counter.floor += 1;
                    },
                    .open => {
                        counter.open += 1;
                    },
                    else => {
                        continue;
                    },
                }
            }
        }
        return counter;
    }

    const NeighborCounts = struct {
        wall: u32,
        floor: u32,
        open: u32,
    };

    pub fn rand_walkers(tiles: []Tile) void {
        _ = tiles;
    }

    pub fn perlin_noise(tiles: []Tile) void {
        _ = tiles;
    }
};

pub const Pathing = struct {
    pub const DijkstraMap = struct {
        map: []f32,
        width: f32,
        height: f32,
        font: ?rl.Font,

        pub fn set_font(self: *@This(), font: rl.Font) void {
            self.font = font;
        }

        pub fn draw(self: @This()) void {
            for (self.map, 0..) |node, i| {
                const index = @as(f32, @floatFromInt(i));
                if (node != -1) {
                    std.debug.print("node: {}", .{node});
                    const node_color = rl.colorFromHSV(@mod(60 - node * 3, 360), 0.8, 1 - 0.01 * node);
                    const rect = rl.Rectangle{
                        .x = @mod(index, self.width) * 16 + 2,
                        .y = @divFloor(index, self.width) * 16 + 2,
                        .width = 16.0 - 4,
                        .height = 16.0 - 4,
                    };
                    rl.drawRectangleRounded(rect, 0.2, 0.0, .fade(node_color, 1.0));
                    //rl.drawTextEx(self.font.?, rl.textFormat("{}", .{node}), .{ .x = @mod(index, self.width) * 16, .y = @divFloor(index, self.width) * 16 }, 16, 2, node_color);
                }
            }
        }

        pub fn deinit(self: *@This()) void {
            self.map.deinit();
        }
    };

    pub fn get_dijkstra_map(grid: Grid, idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !DijkstraMap {
        var queue = std.PriorityQueue(DykstraTracker, void, getDykstraCost).init(allocator, undefined);
        defer queue.deinit();
        var visited = try allocator.alloc(bool, grid.tiles.len);
        var d_map = try allocator.alloc(f32, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }
        for (d_map, 0..) |_, i| {
            d_map[i] = -1;
        }
        const start = DykstraTracker{
            .idx = idx,
            .parent = -1,
            .cost = 1,
            .insert_order = 0,
        };
        try queue.add(start);
        var insert_order: usize = 0;
        while (queue.removeOrNull()) |node| : (insert_order += 1) {
            std.debug.print("node idx: {}\n", .{node.idx});
            visited[@intCast(node.idx)] = true;
            d_map[@intCast(node.idx)] = node.cost;
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
            for (0..neighbors.len) |i| {
                const neighbor = neighbors[i];
                if (neighbor) |u_neighbor| {
                    const queue_index = already_in_queue(&queue, u_neighbor);
                    if (queue_index) |queue_idx| {
                        if (queue.items[queue_idx].cost <= (node.cost + 1)) {
                            continue;
                        } else {
                            _ = queue.removeIndex(queue_idx);
                        }
                    }
                    const new_tracker = DykstraTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                        .cost = node.cost + 1,
                        .insert_order = insert_order,
                    };
                    try queue.add(new_tracker);
                }
            }
        }
        return DijkstraMap{
            .map = d_map,
            .width = @floatFromInt(grid.width),
            .height = @floatFromInt(grid.height),
            .font = null,
        };
    }

    pub const Algorithm = enum {
        dfs,
        bfs,
        dykstra,
        a_star,

        pub fn next(self: *@This()) void {
            switch (self.*) {
                .dfs => {
                    self.* = .bfs;
                },
                .bfs => {
                    self.* = .dykstra;
                },
                .dykstra => {
                    self.* = .a_star;
                },
                .a_star => {
                    self.* = .dfs;
                },
            }
        }
    };

    pub const Mobility = enum {
        orthogonal,
        diagonal,
        pub fn next(self: *@This()) void {
            switch (self.*) {
                .orthogonal => {
                    self.* = .diagonal;
                },
                .diagonal => {
                    self.* = .orthogonal;
                },
            }
        }
    };

    pub fn dfs(grid: Grid, idx: i32, end_idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !void {
        var visited = try allocator.alloc(bool, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }
        const path_found = dfs_helper(grid, @intCast(idx), visited, @intCast(end_idx), path_type, mobility_type);
        if (path_found) {
            std.debug.print("path found\n", .{});
        } else {
            std.debug.print("path not found\n", .{});
        }
    }

    fn dfs_helper(grid: Grid, idx: i32, visited: []bool, end_idx: i32, path_type: TraversalType, mobility_type: Mobility) bool {
        if (idx == end_idx) {
            return true;
        }
        if (is_valid(grid, idx, visited, path_type)) |_| {
            const index: usize = @intCast(idx);

            visited[index] = true;

            const up: i32 = -1 * @as(i32, @intCast(grid.width));
            const down: i32 = grid.width;
            const left: i32 = -1;
            const right: i32 = 1;
            if (dfs_helper(grid, idx + up, visited, end_idx, path_type, mobility_type)) {
                grid.tiles[index].set_state(.traversed);
                return true;
            }
            if (@mod(idx + down, grid.height) != 0) {
                if (dfs_helper(grid, idx + down, visited, end_idx, path_type, mobility_type)) {
                    grid.tiles[index].set_state(.traversed);
                    return true;
                }
            }
            if (@mod(idx + left, grid.width) != grid.width - 1) {
                if (dfs_helper(grid, idx + left, visited, end_idx, path_type, mobility_type)) {
                    grid.tiles[index].set_state(.traversed);
                    return true;
                }
            }
            if (@mod(idx + right, grid.width) != 0) {
                if (dfs_helper(grid, idx + right, visited, end_idx, path_type, mobility_type)) {
                    grid.tiles[index].set_state(.traversed);
                    return true;
                }
            }
            if (mobility_type == .diagonal) {
                if (dfs_helper(grid, idx + up + left, visited, end_idx, path_type, mobility_type)) {
                    grid.tiles[index].set_state(.traversed);
                    return true;
                }
                if (@mod(idx + down + left, grid.height) != 0 and @mod(idx + left, grid.width) != grid.width - 1) {
                    if (dfs_helper(grid, idx + down + left, visited, end_idx, path_type, mobility_type)) {
                        grid.tiles[index].set_state(.traversed);
                        return true;
                    }
                }
                if (@mod(idx + right, grid.width) != 0) {
                    if (dfs_helper(grid, idx + up + right, visited, end_idx, path_type, mobility_type)) {
                        grid.tiles[index].set_state(.traversed);
                        return true;
                    }
                }
                if (@mod(idx + down, grid.height) != 0 and @mod(idx + right, grid.width) != 0) {
                    if (dfs_helper(grid, idx + down + right, visited, end_idx, path_type, mobility_type)) {
                        grid.tiles[index].set_state(.traversed);
                        return true;
                    }
                }
            }

            return false;
        }

        return false;
    }

    const ParentTracker = struct { idx: i32, parent: i32 };

    fn bfs_already_in_queue(queue: std.ArrayList(ParentTracker), index: i32) bool {
        for (queue.items) |item| {
            if (item.idx == index) {
                return true;
            }
        }
        return false;
    }

    pub fn bfs(grid: Grid, idx: i32, end_idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !void {
        var queue: std.ArrayList(ParentTracker) = .empty;
        var path: std.ArrayList(ParentTracker) = .empty;
        defer queue.deinit(allocator);
        defer path.deinit(allocator);
        var visited = try allocator.alloc(bool, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }

        var end_found: bool = false;

        const start = ParentTracker{
            .idx = idx,
            .parent = -1,
        };
        //std.debug.print("bfs idx: {}, bfs parent: {}\n", .{ start.idx, start.parent });
        try queue.append(allocator, start);
        var tiles: u32 = 0;
        while (queue.items.len != 0) : (tiles += 1) {
            var node = queue.orderedRemove(0);
            std.debug.print("bfs idx: {}, bfs parent: {}\n", .{ node.idx, node.parent });

            visited[@intCast(node.idx)] = true;
            try path.append(allocator, node);
            if (node.idx == end_idx) {
                end_found = true;
                break;
            }
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
            //std.debug.print("neighbors: {any}", .{neighbors});
            for (0..neighbors.len) |i| {
                const neighbor = neighbors[i];
                if (neighbor) |u_neighbor| {
                    if (bfs_already_in_queue(queue, u_neighbor)) {
                        continue;
                    }
                    const new_tracker = ParentTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                    };
                    //std.debug.print("bfs idx: {}, bfs parent: {}\n", .{ node.idx, node.parent });
                    try queue.append(allocator, new_tracker);
                }
            }
        }
        if (path.items[path.items.len - 1].idx != end_idx) {
            std.debug.print("Could not find path\n", .{});
            return;
        }
        var curr_search_idx = end_idx;
        while (curr_search_idx != -1) {
            for (path.items) |item| {
                if (item.idx == curr_search_idx) {
                    grid.tiles[@intCast(item.idx)].set_state(.traversed);
                    curr_search_idx = item.parent;
                }
            }
        }
    }

    fn get_neighbors(grid: Grid, idx: i32, visited: []bool, path_type: TraversalType, mobility_type: Mobility) [8]?i32 {
        const up: i32 = -1 * @as(i32, @intCast(grid.width));
        const down: i32 = grid.width;
        const left: i32 = -1;
        const right: i32 = 1;
        const n = idx + up >= 0 and is_valid(grid, idx + up, visited, path_type) != null;
        const s = idx + down < grid.height * grid.width and is_valid(grid, idx + down, visited, path_type) != null;
        const w = @mod(idx, grid.width) != 0 and is_valid(grid, idx + left, visited, path_type) != null;
        const e = @mod(idx, grid.width) != grid.width - 1 and is_valid(grid, idx + right, visited, path_type) != null;
        const nw = idx + up >= 0 and @mod(idx, grid.width) != 0 and is_valid(grid, idx + up + left, visited, path_type) != null;
        const ne = idx + up >= 0 and @mod(idx, grid.width) != grid.width - 1 and is_valid(grid, idx + up + right, visited, path_type) != null;
        const se = idx + down < grid.height * grid.width and @mod(idx, grid.width) != grid.width - 1 and is_valid(grid, idx + down + right, visited, path_type) != null;
        const sw = idx + down < grid.height * grid.width and @mod(idx, grid.width) != 0 and is_valid(grid, idx + down + left, visited, path_type) != null;
        var neighbors: [8]?i32 = .{null} ** 8;
        if (n) {
            neighbors[0] = idx + up;
        }
        if (s) {
            neighbors[1] = idx + down;
        }
        if (w) {
            neighbors[2] = idx + left;
        }
        if (e) {
            neighbors[3] = idx + right;
        }

        switch (mobility_type) {
            .orthogonal => {},
            .diagonal => {
                if (nw) {
                    neighbors[4] = idx + up + left;
                }
                if (sw) {
                    neighbors[5] = idx + down + left;
                }
                if (ne) {
                    neighbors[6] = idx + up + right;
                }
                if (se) {
                    neighbors[7] = idx + down + right;
                }
            },
        }
        return neighbors;
    }

    fn is_valid(grid: Grid, index: ?i32, visited: []bool, path_type: TraversalType) ?i32 {
        if (index) |idx| {
            const rows = grid.height;
            const cols = grid.width;
            const x = @mod(idx, cols);
            const y = @divFloor(idx, cols);
            // check bounds
            //std.debug.print("idx: {}, x: {}, y: {}, rows: {}, cols: {}\n", .{ idx, x, y, rows, cols });
            if (idx < 0 or idx >= grid.tiles.len or 0 > x or x >= cols or 0 > y or y >= rows) {
                return null;
            }
            // check visited or end
            const i: usize = @intCast(idx);
            if (visited[i] == true) {
                return null;
            }

            const tile = grid.tiles[i];
            // check traversible
            if (tile.get_traversible() == .no) {
                return null;
            }

            //std.debug.print("tile_enum: {}, pathing_enum: {}\n", .{ @intFromEnum(tile.traversible), @intFromEnum(path_type) + 1 });
            if (@intFromEnum(tile.get_traversible()) > @as(u16, @intFromEnum(path_type)) + 1) {
                return null;
            }

            return idx;
        }
        return null;
    }

    const DykstraTracker = struct {
        idx: i32,
        parent: i32,
        cost: f32,
        insert_order: usize,
    };
    fn getDykstraCost(context: void, a: DykstraTracker, b: DykstraTracker) std.math.Order {
        _ = context;
        if (a.cost != b.cost) {
            if (a.cost < b.cost) {
                return std.math.Order.lt; // a is less than b
            } else {
                return std.math.Order.gt; // a is greater than b
            }
        } else if (a.insert_order < b.insert_order) {
            return std.math.Order.lt; // a is less than b
        } else {
            return std.math.Order.gt; // a is greater than b
        }
    }

    fn already_in_queue(queue: *std.PriorityQueue(DykstraTracker, void, getDykstraCost), index: i32) ?usize {
        for (queue.items, 0..) |item, i| {
            if (item.idx == index) {
                return i;
            }
        }
        return null;
    }

    pub fn dykstra(grid: Grid, idx: i32, end_idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !void {
        var queue = std.PriorityQueue(DykstraTracker, void, getDykstraCost).init(allocator, undefined);
        var path: std.ArrayList(DykstraTracker) = .empty;
        defer queue.deinit();
        defer path.deinit(allocator);
        var visited = try allocator.alloc(bool, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }

        var end_found: bool = false;

        const start = DykstraTracker{
            .idx = idx,
            .parent = -1,
            .cost = 1,
            .insert_order = 0,
        };
        //std.debug.print("dykstra idx: {}, dykstra parent: {}\n", .{ start.idx, start.parent });
        try queue.add(start);
        var insert_order: usize = 0;
        while (queue.removeOrNull()) |node| : (insert_order += 1) {
            //std.debug.print("dykstra idx: {}, dykstra parent: {}\n", .{ node.idx, node.parent });
            visited[@intCast(node.idx)] = true;
            try path.append(allocator, node);
            if (node.idx == end_idx) {
                end_found = true;
                break;
            }
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
            //std.debug.print("{any}\n", .{neighbors});
            for (0..neighbors.len) |i| {
                const neighbor = neighbors[i];
                if (neighbor) |u_neighbor| {
                    const queue_index = already_in_queue(&queue, u_neighbor);
                    if (queue_index) |queue_idx| {
                        if (queue.items[queue_idx].cost <= (node.cost + 1)) {
                            continue;
                        } else {
                            _ = queue.removeIndex(queue_idx);
                        }
                    }
                    const new_tracker = DykstraTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                        .cost = node.cost + 1,
                        .insert_order = insert_order,
                    };
                    //std.debug.print("bfs idx: {}, bfs parent: {}\n", .{ node.idx, node.parent });
                    try queue.add(new_tracker);
                }
            }
        }
        if (path.items[path.items.len - 1].idx != end_idx) {
            std.debug.print("Could not find path\n", .{});
            return;
        }
        var curr_search_idx = end_idx;
        while (curr_search_idx != -1) {
            for (path.items) |item| {
                if (item.idx == curr_search_idx) {
                    grid.tiles[@intCast(item.idx)].set_state(.traversed);
                    curr_search_idx = item.parent;
                }
            }
        }
    }

    pub fn estimate_path_cost(grid: Grid, index: i32, end_idx: i32) f32 {
        const x: f32 = @as(f32, @rem(@as(f32, @floatFromInt(index)), @as(f32, @floatFromInt(grid.width))));
        const y: f32 = @divExact(@as(f32, @floatFromInt(index)), @as(f32, @floatFromInt(grid.width)));
        const end_x: f32 = @as(f32, @rem(@as(f32, @floatFromInt(end_idx)), @as(f32, @floatFromInt(grid.width))));
        const end_y: f32 = @divExact(@as(f32, @floatFromInt(end_idx)), @as(f32, @floatFromInt(grid.width)));
        const run = end_x - x;
        const rise = end_y - y;
        const cost: f32 = std.math.hypot(run, rise);
        return cost;
    }

    pub fn is_diagonal(grid: Grid, index: i32, new_index: i32) f32 {
        if (index + grid.width == new_index - 1 or index + grid.width - 1 == new_index or index - grid.width + 1 == new_index or index - grid.width - 1 == new_index) {
            return 1.1; // true sqrt(2) was causing issues
        } else {
            return 1;
        }
    }

    pub fn a_star(grid: Grid, idx: i32, end_idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !void {
        var queue = std.PriorityQueue(DykstraTracker, void, getDykstraCost).init(allocator, undefined);
        var path: std.ArrayList(DykstraTracker) = .empty;
        defer queue.deinit();
        defer path.deinit(allocator);
        var visited = try allocator.alloc(bool, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }

        var end_found: bool = false;

        const start = DykstraTracker{
            .idx = idx,
            .parent = -1,
            .cost = estimate_path_cost(grid, idx, end_idx),
            .insert_order = 0,
        };
        //std.debug.print("dykstra idx: {}, dykstra parent: {}\n", .{ start.idx, start.parent });
        try queue.add(start);
        var insert_order: usize = 0;
        while (queue.removeOrNull()) |node| : (insert_order += 1) {
            //std.debug.print("dykstra idx: {}, dykstra parent: {}\n", .{ node.idx, node.parent });
            visited[@intCast(node.idx)] = true;
            try path.append(allocator, node);
            if (node.idx == end_idx) {
                end_found = true;
                break;
            }
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
            //std.debug.print("{any}\n", .{neighbors});
            for (0..neighbors.len) |i| {
                const neighbor = neighbors[i];
                if (neighbor) |u_neighbor| {
                    const cost = node.cost + estimate_path_cost(grid, u_neighbor, end_idx) + is_diagonal(grid, node.idx, u_neighbor);
                    const queue_index = already_in_queue(&queue, u_neighbor);
                    if (queue_index) |queue_idx| {
                        if (queue.items[queue_idx].cost <= cost) {
                            continue;
                        } else {
                            _ = queue.removeIndex(queue_idx);
                        }
                    }
                    const new_tracker = DykstraTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                        .cost = cost,
                        .insert_order = insert_order,
                    };
                    //std.debug.print("bfs idx: {}, bfs parent: {}\n", .{ node.idx, node.parent });
                    try queue.add(new_tracker);
                }
            }
        }
        if (path.items[path.items.len - 1].idx != end_idx) {
            std.debug.print("Could not find path\n", .{});
            return;
        }
        var curr_search_idx = end_idx;
        while (curr_search_idx != -1) {
            for (path.items) |item| {
                if (item.idx == curr_search_idx) {
                    grid.tiles[@intCast(item.idx)].set_state(.traversed);
                    curr_search_idx = item.parent;
                }
            }
        }
    }
};
