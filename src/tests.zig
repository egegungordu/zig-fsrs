const std = @import("std");
const testing = @import("std").testing;
const zig_fsrs = @import("zig-fsrs");
const Rating = zig_fsrs.Rating;
const State = zig_fsrs.State;

test "test intervals" {
    var fsrs = zig_fsrs.FSRS.init(.{
        .w = [17]f32{ 1.0171, 1.8296, 4.4145, 10.9355, 5.0965, 1.3322, 1.017, 0.0, 1.6243, 0.1369, 1.0321, 2.1866, 0.0661, 0.336, 1.7766, 0.1693, 2.9244 },
    });
    var card = zig_fsrs.Card.init();
    var now: i64 = 1669725000;
    var scheduled_cards = fsrs.schedule(card, now);

    const ratings = [13]Rating{ .Good, .Good, .Good, .Good, .Good, .Good, .Again, .Again, .Good, .Good, .Good, .Good, .Good };
    var intervals: [13]i64 = undefined;

    for (ratings, 0..) |rating, i| {
        card = scheduled_cards.select(rating).card;
        intervals[i] = card.scheduled_days;
        now = card.due;

        scheduled_cards = fsrs.schedule(card, now);
    }

    const expected_intervals = [13]i64{ 0, 4, 15, 49, 143, 379, 0, 0, 15, 37, 85, 184, 376 };
    try testing.expectEqualSlices(i64, &expected_intervals, &intervals);
}

test "test states" {
    var fsrs = zig_fsrs.FSRS.init(.{
        .w = [17]f32{ 1.0171, 1.8296, 4.4145, 10.9355, 5.0965, 1.3322, 1.017, 0.0, 1.6243, 0.1369, 1.0321, 2.1866, 0.0661, 0.336, 1.7766, 0.1693, 2.9244 },
    });
    var card = zig_fsrs.Card.init();
    var now: i64 = 1669725000;
    var scheduled_cards = fsrs.schedule(card, now);

    const ratings = [13]Rating{ .Good, .Good, .Good, .Good, .Good, .Good, .Again, .Again, .Good, .Good, .Good, .Good, .Good };
    var states: [13]State = undefined;

    for (ratings, 0..) |rating, i| {
        states[i] = card.state;
        card = scheduled_cards.select(rating).card;
        now = card.due;

        scheduled_cards = fsrs.schedule(card, now);
    }

    const expected_states = [13]State{ .New, .Learning, .Review, .Review, .Review, .Review, .Review, .Relearning, .Relearning, .Review, .Review, .Review, .Review };
    try testing.expectEqualSlices(State, &expected_states, &states);
}
