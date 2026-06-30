const rl = @import("raylib");

max: u32,
curr: u32,

pub fn draw(self: @This(), tile_rect: rl.Rectangle) void {
    const max_rect: rl.Rectangle = rl.Rectangle{
        .x = tile_rect.x,
        .y = tile_rect.y,
        .width = tile_rect.width,
        .height = 4,
    };
    const curr_rect: rl.Rectangle = rl.Rectangle{
        .x = tile_rect.x,
        .y = tile_rect.y,
        .width = tile_rect.width * self.curr / self.max,
        .height = 4,
    };
    
    rl.drawRectangleRec(max_rect, .maroon);
    rl.drawRectangleRec(curr_rect, .red);
}
