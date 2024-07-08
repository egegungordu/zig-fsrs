const std = @import("std");
const fsrs = @import("zig-fsrs");
const Card = fsrs.Card;

pub fn main() !void {
    var f = fsrs.FSRS.init(.{});
    const initial_card = fsrs.Card.init();
    var now = std.time.timestamp();
    var s = f.repeat(initial_card, now);

    // good was selected on new card
    const first_rep = s.select(.Good).card;
    now = first_rep.due;

    // good was selected on learning card
    s = f.repeat(first_rep, now);
    const second_rep = s.select(.Good).card;
    now = second_rep.due;

    // again was selected on review card
    s = f.repeat(second_rep, now);
    const third_rep = s.select(.Again).card;
    now = third_rep.due;

    print_card(&initial_card, "Initial card");
    print_card(&first_rep, "First rep");
    print_card(&second_rep, "Second rep");
    print_card(&third_rep, "Third rep");
}

fn print_card(card: *const Card, title: []const u8) void {
    std.debug.print("{s}\n", .{title});
    std.debug.print("  state: {s}\n", .{@tagName(card.state)});
    std.debug.print("  reps: {d}\n", .{card.reps});
    std.debug.print("  lapses: {d}\n", .{card.lapses});
    std.debug.print("  stability: {d}\n", .{card.stability});
    std.debug.print("  difficulty: {d}\n", .{card.difficulty});
    std.debug.print("  elapsed days: {d}\n", .{card.elapsed_days});
    std.debug.print("  scheduled days: {d}\n", .{card.scheduled_days});
    std.debug.print("  due: {d}\n", .{card.due});
}
