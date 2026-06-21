const std = @import("std");
const rl = @import("raylib");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Io = std.Io;

const Grid = @import("Grid.zig");
const Tile = @import("Tile.zig");
const EventLog = @import("EventLog.zig");
const TraversalType = Tile.TraversalType;

pub const Generation = struct {

    pub const MapState = struct {
        algo: Algorithm,
        reset: bool,
    };

    pub const Algorithm = enum {
        ca,
        bsp,
        voronoi,
        noise,

        pub fn next(self: *@This(), logger: *EventLog) void {
            switch (self.*) {
                .ca => {
                    self.* = .bsp;
                    logger.log(
                        "Selected {} Generation.",
                        .info,
                        &.{.{
                            .text = "Binary Space Partition",
                            .effect = .shimmer,
                            .color1 = .blue,
                            .color2 = .pink,
                        }}
                    );
                },
                .bsp => {
                    self.* = .voronoi;
                    logger.log(
                        "Selected {} Generation.",
                        .info,
                        &.{.{
                            .text = "Voronoi",
                            .effect = .shimmer,
                            .color1 = .purple,
                            .color2 = .maroon,
                        }}
                    );
                },
                .voronoi => {
                    self.* = .noise;
                    logger.log(
                        "Selected {} Generation.",
                        .info,
                        &.{.{
                            .text = "Perlin Noise",
                            .effect = .shimmer,
                            .color1 = .red,
                            .color2 = .orange,
                        }}
                    );
                },
                .noise => {
                    self.* = .ca;
                    logger.log(
                        "Selected {} Generation.",
                        .info,
                        &.{.{
                            .text = "Cellular Automata",
                            .effect = .shimmer,
                            .color1 = .green,
                            .color2 = .yellow,
                        }}
                    );
                },
            }
        }
    };

    pub fn c_a(grid: Grid, iterations: u8, io: Io, allocator: Allocator) !void {
        const rng_impl: std.Random.IoSource = .{ .io = io };
        const rand = rng_impl.interface();
        //var seed: u64 = undefined;
        //std.crypto.random.bytes(std.mem.asBytes(&seed));
        //var prng = std.Random.DefaultPrng.init(seed);
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

    const Area = struct {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    };

    const Direction = enum {
        horizontal,
        vertical,
    };

    pub fn bsp(grid: Grid, io: Io, allocator: std.mem.Allocator) !void {
        grid.fill(.wall);
        var to_split: ArrayList(Area) = .empty;
        defer to_split.deinit(allocator);
        var rooms: ArrayList(Area) = .empty;
        defer rooms.deinit(allocator);
        const rng_impl: std.Random.IoSource = .{ .io = io };
        const rand = rng_impl.interface();
        var keep_going = true;
        const grid_area = Area{
            .x = 0,
            .y = 0,
            .width = grid.width,
            .height = grid.height,
        };
        try to_split.append(allocator, grid_area);
        var counter: u32 = 0;
        while (keep_going) {
            const current = to_split.pop();
            var direction = rand.enumValue(Direction);
            if (current) |u_current| {
                if (u_current.width < 12) {
                    direction = .vertical;
                } else if (u_current.height < 12) {
                    direction = .horizontal;
                }
                if (u_current.width > 3 and u_current.width < 12 and u_current.height > 3 and u_current.height < 12) {
                    counter = counter + 1;
                    // area is small enough
                    const width = rand.intRangeAtMost(u32, 3, u_current.width - 1);
                    const height = rand.intRangeAtMost(u32, 3, u_current.height - 1);
                    const x_shift = rand.intRangeAtMost(u32, 1, u_current.width - width);
                    const y_shift = rand.intRangeAtMost(u32, 1, u_current.height - height);
                    const room = Area{
                        .x = u_current.x + x_shift,
                        .y = u_current.y + y_shift,
                        .width = width,
                        .height = height,
                    };
                    std.debug.print("{}\n", .{counter});
                    // make rooms
                    try rooms.append(allocator, room);
                    continue;
                }
                switch (direction) {
                    .vertical => {
                        const split_height = rand.intRangeAtMost(u32, 4, u_current.height - 4);
                        const top = Area{
                            .x = u_current.x,
                            .y = u_current.y,
                            .width = u_current.width,
                            .height = split_height,
                        };
                        const bottom = Area{
                            .x = u_current.x,
                            .y = u_current.y + split_height,
                            .width = u_current.width,
                            .height = u_current.height - split_height,
                        };
                        try to_split.append(allocator, top);
                        try to_split.append(allocator, bottom);
                    },
                    .horizontal => {
                        const split_width = rand.intRangeAtMost(u32, 4, u_current.width - 4);
                        const left = Area{
                            .x = u_current.x,
                            .y = u_current.y,
                            .width = split_width,
                            .height = u_current.height,
                        };
                        const right = Area{
                            .x = u_current.x + split_width,
                            .y = u_current.y,
                            .width = u_current.width - split_width,
                            .height = u_current.height,
                        };
                        try to_split.append(allocator, left);
                        try to_split.append(allocator, right);
                    },
                }
            }
            if (to_split.items.len == 0) {
                keep_going = false;
            }
        }

        for (rooms.items, 0..) |item, i| {
            // create a room with %80 probability
            const room = Area{
                .x = item.x,
                .y = item.y,
                .width = item.width,
                .height = item.height,
            };
            for (room.x..(room.x + room.width)) |x| {
                for (room.y..(room.y + room.height)) |y| {
                    grid.tiles[x + (y * grid.width) - 1].set_type(.floor);
                }
            }
            // dog legs
            var other_room_a: i32 = -1;
            var other_room_b: i32 = -1;
            var other_room: i32 = -1;
            if (i > 0) {
                other_room_a = rand.intRangeAtMost(i32, 0, @intCast(i - 1));
            }
            if (i < rooms.items.len - 1) {
                other_room_b = rand.intRangeAtMost(i32, @intCast(i + 1), @intCast(rooms.items.len - 1));
            }
            if (other_room_a > -1 and other_room_b > -1) {
                if (rand.float(f32) > 0.5) {
                    other_room = other_room_a;
                } else {
                    other_room = other_room_b;
                }
            } else if (other_room_a > -1) {
                other_room = other_room_a;
            } else if (other_room_b > -1) {
                other_room = other_room_b;
            } else {
                unreachable;
            }
            const room_b: Area = rooms.items[@intCast(other_room)];

            // pick point in room
            const point_a = .{
                .x = rand.intRangeAtMost(u32, room.x + 1, room.x + room.width - 2),
                .y = rand.intRangeAtMost(u32, room.y + 1, room.y + room.height - 2),
            };

            std.debug.print("room a: {}, point a: {}\n", .{room, point_a});

            // pick point in other room
            const point_b = .{
                .x = rand.intRangeAtMost(u32, room_b.x + 1, room_b.x + room_b.width - 2),
                .y = rand.intRangeAtMost(u32, room_b.y + 1, room_b.y + room_b.height - 2),
            };
            std.debug.print("room b: {}, point b: {}\n", .{room_b, point_b});

            // draw horizontal
            const x_dist: i32 = @as(i32, @intCast(point_a.x)) - @as(i32, @intCast(point_b.x));
            std.debug.print("x_dist: {} ", .{x_dist});
            if (x_dist >= 0) {
                for (0..@intCast(x_dist + 1)) |j| {
                    grid.tiles[point_b.x + j + (point_a.y * grid.width)].set_type(.floor);
                }
            } else {
                std.debug.print("lateral: {}", .{@as(u32, @intCast(-x_dist + 1))});
                for (0..@intCast((-x_dist) + 1)) |j| {
                    grid.tiles[point_a.x + j + (point_a.y * grid.width)].set_type(.floor);
                }
            }
            
            // draw vertical
            const y_dist: i32 = @as(i32, @intCast(point_a.y)) - @as(i32, @intCast(point_b.y));
            std.debug.print("y_dist: {}\n", .{y_dist});
            if (y_dist >= 0) {
                for (0..@intCast(y_dist + 1)) |j| {
                    grid.tiles[point_b.x + ((point_b.y + j) * grid.width)].set_type(.floor);
                }
            } else {
                for (0..@intCast((-y_dist) + 1)) |j| {
                    grid.tiles[point_b.x + ((point_a.y + j) * grid.width)].set_type(.floor);
                }
            }

        }

        grid.fix_edges();
    }

    const Point = struct {
        x: u32,
        y: u32,
    };


    const NNeighbor = struct {
        index: u32,
        distance: f32,
        node: Point
    };

    pub fn voronoi(grid: Grid, io: Io, allocator: Allocator) !void {
        const rng_impl: std.Random.IoSource = .{ .io = io };
        const rand = rng_impl.interface();
        var points: std.ArrayList(Point) = .empty;
        defer points.deinit(allocator);
        
        for (0..6) |_| {
            const rand_point = Point{
                .x = rand.intRangeAtMost(u32, 3, grid.width - 3),
                .y = rand.intRangeAtMost(u32, 3, grid.height - 3),
            };
            try points.append(allocator, rand_point);
        }
        for (0..grid.tiles.len) |j| {
            var curr_nn: ?NNeighbor = null;
            for (points.items, 0..) |point, i| {
                // calculate euclidean distance
                const x_diff: f32 = @as(f32, @floatFromInt(j % grid.width)) - @as(f32, @floatFromInt(point.x));
                const y_diff: f32 = @as(f32, @floatFromInt(j / grid.width)) - @as(f32, @floatFromInt(point.y));
                const distance: f32 = @sqrt((x_diff * x_diff) + (y_diff * y_diff));
                if (curr_nn) |u_curr_nn| {
                    if (distance < u_curr_nn.distance) {
                        curr_nn = NNeighbor{
                            .index = @intCast(i),
                            .distance = distance,
                            .node = point,
                        };
                    }
                } else {
                    curr_nn = NNeighbor{
                        .index = @intCast(i),
                        .distance = distance,
                        .node = point,
                    };
                }
            }
            const node_color = rl.colorFromHSV(@floatFromInt(@mod(60 * curr_nn.?.index, 360)), 0.8, 1.0);
            if (j % grid.width == curr_nn.?.node.x and j / grid.width == curr_nn.?.node.y) {
                grid.tiles[j].set_custom_color(.black);
            } else {
                grid.tiles[j].set_custom_color(node_color);
            }
        }
    }

    pub fn noise(grid: Grid, io: Io, allocator: Allocator) !void {
        var x_off: f32 = 0.0;
        var y_off: f32 = 0.0;
        var perlin_arr: std.ArrayList(f32) = .empty;
        for (0..grid.tiles.len) |i| {
            const x = i % grid.width;
            if (x == 0) {
                x_off = 0.0;
                y_off += 0.1;
            } else {
                x_off += 0.1;
            }
            const p_noise: f32 = try perlin_noise(.{.x = x_off, .y = y_off, .p_arr = &perlin_arr}, io, allocator);
            std.debug.print("noise: {}\n", .{p_noise});
            if (p_noise > 0.8) {
                grid.tiles[i].set_custom_color(.white);
            } else if (p_noise > 0.7) {
                grid.tiles[i].set_custom_color(rl.Color{.r = @floor(p_noise * 0.9 * 255), .g = @floor(p_noise * 0.8 * 255), .b = @floor(p_noise * 0.7 * 255), .a = 0});
            } else if (p_noise > 0.5) {
                grid.tiles[i].set_custom_color(rl.Color{.r = @floor(p_noise * 0.1 * 255), .g = @floor(p_noise * 0.8 * 255), .b = @floor(p_noise * 0.25 * 255), .a = 0});
            } else {
                grid.tiles[i].set_custom_color(rl.Color{.r = @floor(((1 - p_noise) * 255) * 0.1), .g = @floor(((1 - p_noise) * 255) * 0.25), .b = @floor(((1 - p_noise) * 255) * 1.0), .a = 0});
            }
        }
        perlin_arr.deinit(allocator);
    }

    const PERLIN_YWRAPB = 4;
    const PERLIN_YWRAP = 1 << PERLIN_YWRAPB;
    const PERLIN_ZWRAPB = 8;
    const PERLIN_ZWRAP = 1 << PERLIN_ZWRAPB;
    const PERLIN_SIZE = 4095;

    var perlin_octaves: u16 = 4;
    var perlin_amp_falloff: f32 = 0.5;

    fn scaled_cosine(i: f32) f32 {
        return 0.5 * (1.0 - std.math.cos(i * std.math.pi));
    }

    const PerlinConfig = struct {
        x: f32,
        y: f32 = 0,
        z: f32 = 0,
        p_arr: *std.ArrayList(f32),
    };

    fn perlin_noise(args: PerlinConfig, io: Io, allocator: Allocator) !f32 {
        const rng_impl: std.Random.IoSource = .{ .io = io };
        const rand = rng_impl.interface();
        var perlin_arr = args.p_arr;
        if (perlin_arr.items.len == 0) {
            for (0..PERLIN_SIZE + 1) |_| {
              try perlin_arr.append(allocator, rand.float(f32));
            }
        }
        var x = args.x;
        var y = args.y;
        var z = args.z;

        if (x < 0) {
            x = -x;
        }
        if (y < 0) {
            y = -y;
        }
        if (z < 0) {
            z = -z;
        }

        var xi: u32 = @floor(x);
        var yi: u32 = @floor(y);
        var zi: u32 = @floor(z);

        var xf: f32 = x - @as(f32, @floatFromInt(xi));
        var yf: f32 = y - @as(f32, @floatFromInt(yi));
        var zf: f32 = z - @as(f32, @floatFromInt(zi));

        var r: f32 = 0;
        var ampl: f32 = 0.5;

        var n1: f32 = 0.0;
        var n2: f32 = 0.0; 
        var n3: f32 = 0.0;

        for (0..perlin_octaves) |_| {
            var of = xi + (yi << PERLIN_YWRAPB);

            const rxf = scaled_cosine(xf);
            const ryf = scaled_cosine(yf);

            n1 = perlin_arr.items[of & PERLIN_SIZE];
            n1 += rxf * (perlin_arr.items[(of + 1) & PERLIN_SIZE] - n1);
            n2 = perlin_arr.items[(of + PERLIN_YWRAP) & PERLIN_SIZE];
            n2 += rxf * (perlin_arr.items[(of + PERLIN_YWRAP + 1) & PERLIN_SIZE] - n2);
            n1 += ryf * (n2 - n1);

            of += PERLIN_ZWRAP;
            n2 = perlin_arr.items[of & PERLIN_SIZE];
            n2 += rxf * (perlin_arr.items[(of + 1) & PERLIN_SIZE] - n2);
            n3 = perlin_arr.items[(of + PERLIN_YWRAP) & PERLIN_SIZE];
            n3 += rxf * (perlin_arr.items[(of + PERLIN_YWRAP + 1) & PERLIN_SIZE] - n3);
            n2 += ryf * (n3 - n2);

            n1 += scaled_cosine(zf) * (n2 - n1);

            r += n1 * ampl;
            ampl *= perlin_amp_falloff;
            xi <<= 1;
            xf *= 2;
            yi <<= 1;
            yf *= 2;
            zi <<= 1;
            zf *= 2;

            if (xf >= 1.0) {
                xi += 1;
                xf -= 1;
            }
            if (yf >= 1.0) {
                yi += 1;
                yf -= 1;
            }
            if (zf >= 1.0) {
                zi += 1;
                zf -= 1;
            }
        }
        return r;
    }
};

pub const Pathing = struct {
    pub const DijkstraMap = struct {
        map: []f32,
        x: u16,
        y: u16,
        width: f32,
        height: f32,
        tileSize: f32,
        font: ?rl.Font,
        max_cost: f32,

        pub fn set_font(self: *@This(), font: rl.Font) void {
            self.font = font;
        }

        pub fn draw(self: @This()) void {
            var cost_weight: f32 = 0.01;
            if (self.max_cost != -1 and self.max_cost > 99) {
                cost_weight = 0.95 / self.max_cost;
            }
            std.debug.print("cost_weight: {}", .{cost_weight});
            for (self.map, 0..) |node, i| {
                const index = @as(f32, @floatFromInt(i));
                if (node != -1) {
                    const node_color = rl.colorFromHSV(@mod(60 - node * 3.0, 360), 0.8, 1 - cost_weight * node);
                    const rect = rl.Rectangle{
                        .x = @mod(index, self.width) * self.tileSize + self.x,
                        .y = @divFloor(index, self.width) * self.tileSize + self.y,
                        .width = self.tileSize,
                        .height = self.tileSize,
                    };
                    rl.drawRectangleRounded(rect, 0.0, 0.0, .fade(node_color, 1.0));
                }
            }
        }

        pub fn deinit(self: *@This()) void {
            self.map.deinit();
        }
    };

    pub fn get_dijkstra_map(grid: Grid, tileSize: f32, idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !DijkstraMap {
        var queue: std.PriorityQueue(DijkstraTracker, void, getDijkstraCost) = .empty;
        defer queue.deinit(allocator);
        var visited = try allocator.alloc(bool, grid.tiles.len);
        var d_map = try allocator.alloc(f32, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }
        for (d_map, 0..) |_, i| {
            d_map[i] = -1;
        }
        const start = DijkstraTracker{
            .idx = idx,
            .parent = -1,
            .cost = 1,
            .insert_order = 0,
        };
        try queue.push(allocator, start);
        var insert_order: usize = 0;
        var max_cost: f32 = -1;
        while (queue.pop()) |node| : (insert_order += 1) {
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
                            _ = queue.popIndex(queue_idx);
                        }
                    }
                    if (max_cost < node.cost + 1) {
                        max_cost = node.cost + 1;
                    }
                    const new_tracker = DijkstraTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                        .cost = node.cost + 1,
                        .insert_order = insert_order,
                    };
                    try queue.push(allocator, new_tracker);
                }
            }
        }
        return DijkstraMap{
            .map = d_map,
            .x = grid.padding_x * @as(u16, @intFromFloat(grid.tile_ps)),
            .y = grid.padding_y * @as(u16, @intFromFloat(grid.tile_ps)),
            .width = @floatFromInt(grid.width),
            .height = @floatFromInt(grid.height),
            .tileSize = tileSize,
            .font = null,
            .max_cost = max_cost,
        };
    }

    pub const Algorithm = enum {
        dfs,
        bfs,
        dijkstra,
        a_star,

        pub fn next(self: *@This(), logger: *EventLog) void {
            switch (self.*) {
                .dfs => {
                    self.* = .bfs;
                    logger.log(
                        "Selected {} Pathing.",
                        .info,
                        &.{.{
                            .text = "Breadth First Search",
                            .effect = .fading,
                            .color1 = .blue,
                        }}
                    );
                },
                .bfs => {
                    self.* = .dijkstra;
                    logger.log(
                        "Selected {} Pathing.",
                        .info,
                        &.{.{
                            .text = "Dijkstra",
                            .effect = .fading,
                            .color1 = .green,
                        }}
                    );
                },
                .dijkstra => {
                    self.* = .a_star;
                    logger.log(
                        "Selected {} Pathing.",
                        .info,
                        &.{.{
                            .text = "A*",
                            .effect = .fading,
                            .color1 = .purple,
                        }}
                    );
                },
                .a_star => {
                    self.* = .dfs;
                    logger.log(
                        "Selected {} Pathing.",
                        .info,
                        &.{.{
                            .text = "Depth First Search",
                            .effect = .fading,
                            .color1 = .red,
                        }}
                    );
                },
            }
        }
    };

    pub const Mobility = enum {
        orthogonal,
        diagonal,
        pub fn next(self: *@This(), logger: *EventLog) void {
            switch (self.*) {
                .orthogonal => {
                    self.* = .diagonal;
                    logger.log(
                        "You feel {} agile.",
                        .alert,
                        &.{.{
                            .text = "more",
                            .effect = .flat,
                            .color1 = .green,
                        }}
                    );
                },
                .diagonal => {
                    self.* = .orthogonal;
                    logger.log(
                        "You feel {} agile.",
                        .alert,
                        &.{.{
                            .text = "less",
                            .effect = .flat,
                            .color1 = .red,
                        }}
                    );
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
        if (!path_found) {
            std.debug.print("Could not find path\n", .{});
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
        try queue.append(allocator, start);
        var tiles: u32 = 0;
        while (queue.items.len != 0) : (tiles += 1) {
            const node = queue.orderedRemove(0);

            visited[@intCast(node.idx)] = true;
            try path.append(allocator, node);
            if (node.idx == end_idx) {
                end_found = true;
                break;
            }
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
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
        var neighbors: [8]?i32 = @splat(null);
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

            if (@intFromEnum(tile.get_traversible()) > @as(u16, @intFromEnum(path_type)) + 1) {
                return null;
            }

            return idx;
        }
        return null;
    }

    const DijkstraTracker = struct {
        idx: i32,
        parent: i32,
        cost: f32,
        insert_order: usize,
    };
    fn getDijkstraCost(context: void, a: DijkstraTracker, b: DijkstraTracker) std.math.Order {
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

    fn already_in_queue(queue: *std.PriorityQueue(DijkstraTracker, void, getDijkstraCost), index: i32) ?usize {
        for (queue.items, 0..) |item, i| {
            if (item.idx == index) {
                return i;
            }
        }
        return null;
    }

    pub fn dijkstra(grid: Grid, idx: i32, end_idx: i32, path_type: TraversalType, mobility_type: Mobility, allocator: std.mem.Allocator) !void {
        var queue: std.PriorityQueue(DijkstraTracker, void, getDijkstraCost) = .empty;
        var path: std.ArrayList(DijkstraTracker) = .empty;
        defer queue.deinit(allocator);
        defer path.deinit(allocator);
        var visited = try allocator.alloc(bool, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }

        var end_found: bool = false;

        const start = DijkstraTracker{
            .idx = idx,
            .parent = -1,
            .cost = 1,
            .insert_order = 0,
        };
        try queue.push(allocator, start);
        var insert_order: usize = 0;
        while (queue.pop()) |node| : (insert_order += 1) {
            visited[@intCast(node.idx)] = true;
            try path.append(allocator, node);
            if (node.idx == end_idx) {
                end_found = true;
                break;
            }
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
            for (0..neighbors.len) |i| {
                const neighbor = neighbors[i];
                if (neighbor) |u_neighbor| {
                    const queue_index = already_in_queue(&queue, u_neighbor);
                    if (queue_index) |queue_idx| {
                        if (queue.items[queue_idx].cost <= (node.cost + 1)) {
                            continue;
                        } else {
                            _ = queue.popIndex(queue_idx);
                        }
                    }
                    const new_tracker = DijkstraTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                        .cost = node.cost + 1,
                        .insert_order = insert_order,
                    };
                    try queue.push(allocator, new_tracker);
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
        var queue: std.PriorityQueue(DijkstraTracker, void, getDijkstraCost) = .empty;
        var path: std.ArrayList(DijkstraTracker) = .empty;
        defer queue.deinit(allocator);
        defer path.deinit(allocator);
        var visited = try allocator.alloc(bool, grid.tiles.len);
        defer allocator.free(visited);
        for (visited, 0..) |_, i| {
            visited[i] = false;
        }

        var end_found: bool = false;

        const start = DijkstraTracker{
            .idx = idx,
            .parent = -1,
            .cost = estimate_path_cost(grid, idx, end_idx),
            .insert_order = 0,
        };
        try queue.push(allocator, start);
        var insert_order: usize = 0;
        while (queue.pop()) |node| : (insert_order += 1) {
            visited[@intCast(node.idx)] = true;
            try path.append(allocator, node);
            if (node.idx == end_idx) {
                end_found = true;
                break;
            }
            const neighbors = get_neighbors(grid, node.idx, visited, path_type, mobility_type);
            for (0..neighbors.len) |i| {
                const neighbor = neighbors[i];
                if (neighbor) |u_neighbor| {
                    const cost = node.cost + estimate_path_cost(grid, u_neighbor, end_idx) + is_diagonal(grid, node.idx, u_neighbor);
                    const queue_index = already_in_queue(&queue, u_neighbor);
                    if (queue_index) |queue_idx| {
                        if (queue.items[queue_idx].cost <= cost) {
                            continue;
                        } else {
                            _ = queue.popIndex(queue_idx);
                        }
                    }
                    const new_tracker = DijkstraTracker{
                        .idx = u_neighbor,
                        .parent = node.idx,
                        .cost = cost,
                        .insert_order = insert_order,
                    };
                    try queue.push(allocator, new_tracker);
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
