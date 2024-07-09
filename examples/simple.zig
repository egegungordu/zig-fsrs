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

    std.debug.print("initial card:\n{}\n\n", .{initial_card});
    std.debug.print("after first rep (good):\n{}\n\n", .{first_rep});
    std.debug.print("after second rep (good):\n{}\n\n", .{second_rep});
    std.debug.print("after third rep (again):\n{}\n\n", .{third_rep});
}
