const std = @import("std");
const rl = @import("raylib");

const Allocator = std.mem.Allocator;

const Button = @import("Button.zig").Button;
const toggle_on_click = @import("Button.zig").toggle_on_click;

pub const State = enum{
    main_menu,
    game,

    fn next(self: *@This()) void {
        switch (self.*) {
            .main_menu => self.* = .game,
            .game => self.* = .main_menu,
        }
    }
};

const h_btn_pad = 64;
const v_btn_pad = 32;

state: *State,
close_state: *bool,
font: rl.Font,
background: rl.Texture2D,
btn_box: rl.Rectangle,
buttons: std.ArrayList(Button),
selected: u16,

pub fn init(screen_pw: f32, screen_ph: f32, btn_pw: f32, btn_ph: f32, tile_ps: f32, state: *State, font: rl.Font, btn_tileset: rl.Texture2D, background: rl.Texture2D, close_state: *bool, allocator: Allocator) !@This() {
    const buttons = try generate_buttons(screen_pw, screen_ph, btn_pw, btn_ph, tile_ps, font, btn_tileset, state, close_state, allocator);
    const btn_box = create_btn_box(@intCast(buttons.items.len), screen_pw, screen_ph, btn_pw, btn_ph);
    return @This(){
        .state = state,
        .close_state = close_state,
        .font = font,
        .background = background,
        .btn_box = btn_box,
        .buttons = buttons,
        .selected = 0,
    };
}

pub fn draw(self: @This()) void {
    rl.drawTextureV(
        self.background,
        .{.x = 0, .y = 0},
        rl.Color.init(255, 255, 255, 100),
    );
    rl.drawRectangleRec(self.btn_box, .dark_gray);

    const highlight_rec = self.get_highlight_rec();
    rl.drawRectangleRec(highlight_rec, .light_gray);
    for (self.buttons.items) |u_button| {
        u_button.draw();
    }
}

pub fn handle_input(self: *@This()) void {
    if (rl.isMouseButtonPressed(.left)) {
        const m_cursor = rl.getMousePosition();
        for (self.buttons.items) |*u_btn| {
            if (rl.checkCollisionPointRec(m_cursor, u_btn.rect)) {
                u_btn.on_click(u_btn);
            }
        }
    }
    switch (rl.getKeyPressed()) {
        .escape => {
            self.close_state.* = true;
        },
        .kp_8, .up, .s => {
            if (self.selected > 0) {
                self.selected -= 1;
            }
        },
        .kp_2, .down, .w => {
            if (self.selected < self.buttons.items.len - 1) {
                self.selected += 1;
            }
        },
        .enter => {
            var btn = self.buttons.items[self.selected];
            btn.on_click(&btn);
        },
        else => {
            // do nothing
        },
    }
}


fn generate_buttons(screen_pw: f32, screen_ph: f32, btn_pw: f32, btn_ph: f32, tile_ps: f32, font: rl.Font, btn_tileset: rl.Texture2D, menu_state: *State, close_state: *bool, allocator: Allocator) !std.ArrayList(Button) {
    var buttons: std.ArrayList(Button) = .empty;
    const x = (screen_pw - btn_pw) / 2;  
    const height = (2 * btn_ph + 3 * v_btn_pad);
    var y = (screen_ph - height) / 2 + v_btn_pad;

    const start_btn = Button.init(.{
        .rect = .{
            .x = x,
            .y = y,
            .width = btn_pw,
            .height = btn_ph,
        },
        .tile_ps = tile_ps,
        .message = "Start"[0..],
        .color = .dark_green,
        .text_color = .light_gray,
        .font = font,
        .tileset = btn_tileset,
        .logger = undefined,
        .on_click = menu_on_click,
        .state = menu_state,
    });
    y += btn_ph + 32;
    const exit_btn = Button.init(.{
        .rect = .{
            .x = x,
            .y = y,
            .width = btn_pw,
            .height = btn_ph,
        },
        .tile_ps = tile_ps,
        .message = "Quit"[0..],
        .color = .maroon,
        .text_color = .gold,
        .font = font,
        .tileset = btn_tileset,
        .logger = undefined,
        .on_click = toggle_on_click,
        .state = close_state,
    });
    try buttons.append(allocator, start_btn);
    try buttons.append(allocator, exit_btn);
    return buttons;
}

fn create_btn_box(btn_count: u32, screen_pw: f32, screen_ph: f32, btn_pw: f32, btn_ph: f32) rl.Rectangle {
    const width = (btn_pw + 2 * h_btn_pad);
    const height = ((btn_ph + v_btn_pad) * @as(f32, @floatFromInt(btn_count))) + v_btn_pad;
    const x = (screen_pw - width) / 2; 
    const y = (screen_ph - height) / 2;
    return rl.Rectangle{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

fn get_highlight_rec(self: @This()) rl.Rectangle {
    const button_rect = self.buttons.items[self.selected].rect;
    const hl_size = 2;
    return rl.Rectangle{
        .x = button_rect.x - hl_size,
        .y = button_rect.y - hl_size,
        .width = button_rect.width + 2 * hl_size,
        .height = button_rect.height + 2 * hl_size,
    };
}

fn menu_on_click(self: *Button) void {
    const menu_state: *State = @ptrCast(self.state);
    menu_state.next();
}
