const std = @import("std");
const ArrayList = std.ArrayList;

const rl = @import("raylib");

pub const MessageType = enum {
    info, //white/gray
    alert, //yellow
    warning, //maroon

    pub fn get_color(self: @This()) rl.Color {
        return switch (self) {
            .warning => .maroon,
            .info => .light_gray,
            .alert => .yellow,
        };
    }
};

pub const HighlightEffect = enum {
    flat,
    shimmer,
    fading,
};

pub const TextHighlight = struct {
    text: []const u8,
    effect: HighlightEffect,
    color1: rl.Color,
    color2: rl.Color = .white,
    pub fn get_effect(self: @This()) HighlightEffect {
        return self.effect;
    }

    pub fn get_color1(self: @This()) rl.Color {
        return self.color1;
    }

    pub fn get_color2(self: @This()) rl.Color {
        return self.color2;
    }
};

text: []const u8,
type: MessageType,
hl_text: []const TextHighlight,

