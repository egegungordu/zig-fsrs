const std = @import("std");

const Models = @import("models.zig");
const Parameters = Models.Parameters;
const Card = Models.Card;
const SchedulingCards = Models.SchedulingCards;
const ScheduledCards = Models.ScheduledCards;
const Rating = Models.Rating;

const Self = @This();

params: Parameters,

pub fn init(params: Parameters) Self {
    return .{
        .params = params,
    };
}

pub fn repeat(self: Self, card: Card, now: i64) ScheduledCards {
    const minute = 60;
    const day = 24 * 60 * 60;
    var c = card;

    if (c.state == .New) {
        c.elapsed_days = 0;
    } else {
        c.elapsed_days = @divFloor(now - c.last_review, day);
    }

    c.last_review = now;
    c.reps += 1;
    var s = SchedulingCards.init(&c);
    s.updateState(card.state);

    switch (card.state) {
        .New => {
            s.again.stability = self.initStability(.Again);
            s.again.difficulty = self.initDifficulty(.Again);
            s.hard.stability = self.initStability(.Hard);
            s.hard.difficulty = self.initDifficulty(.Hard);
            s.good.stability = self.initStability(.Good);
            s.good.difficulty = self.initDifficulty(.Good);
            s.easy.stability = self.initStability(.Easy);
            s.easy.difficulty = self.initDifficulty(.Easy);

            const easy_interval = self.nextInterval(s.easy.stability);

            s.again.due = now + 1 * minute;
            s.hard.due = now + 5 * minute;
            s.good.due = now + 10 * minute;
            s.easy.scheduled_days = easy_interval;
            s.easy.due = now + easy_interval * day;
        },
        .Learning, .Relearning => {
            const good_interval = self.nextInterval(s.good.stability);
            const easy_interval = @max(good_interval + 1, self.nextInterval(s.easy.stability));

            s.again.scheduled_days = 0;
            s.again.due = now + 5 * minute;
            s.hard.scheduled_days = 0;
            s.hard.due = now + 10 * minute;
            s.good.scheduled_days = good_interval;
            s.good.due = now + good_interval * day;
            s.easy.scheduled_days = easy_interval;
            s.easy.due = now + easy_interval * day;
        },
        .Review => {
            s.again.stability = self.nextForgetStability(&c);
            s.again.difficulty = self.nextDifficulty(&c, .Again);
            s.hard.stability = self.nextRecallStability(&c, .Hard);
            s.hard.difficulty = self.nextDifficulty(&c, .Hard);
            s.good.stability = self.nextRecallStability(&c, .Good);
            s.good.difficulty = self.nextDifficulty(&c, .Good);
            s.easy.stability = self.nextRecallStability(&c, .Easy);
            s.easy.difficulty = self.nextDifficulty(&c, .Easy);

            var hard_interval = self.nextInterval(s.hard.stability);
            var good_interval = self.nextInterval(s.good.stability);
            var easy_interval = self.nextInterval(s.easy.stability);

            hard_interval = @min(hard_interval, good_interval);
            good_interval = @max(good_interval, hard_interval + 1);
            easy_interval = @max(easy_interval, good_interval + 1);

            s.again.scheduled_days = 0;
            s.again.due = now + 5 * minute;
            s.hard.scheduled_days = hard_interval;
            s.hard.due = now + hard_interval * day;
            s.good.scheduled_days = good_interval;
            s.good.due = now + good_interval * day;
            s.easy.scheduled_days = easy_interval;
            s.easy.due = now + easy_interval * day;
        },
    }

    return s.toScheduledCards(now);
}

fn initStability(self: Self, rating: Rating) f32 {
    return @max(self.params.w[@intFromEnum(rating) - 1], 0.1);
}

fn initDifficulty(self: Self, rating: Rating) f32 {
    // zig fmt: off
    const difficulty = @mulAdd(
        f32, 
        self.params.w[5], 
        -(@as(f32, @floatFromInt(@intFromEnum(rating))) - 3.0), 
        self.params.w[4]
    );
    // zig fmt: on

    return @min(10, @max(1, difficulty));
}

fn forgettingCurve(elapsed_days: i64, stability: f32) f32 {
    // zig fmt: off
    return std.math.pow(
        f32, 
        1.0 + Parameters.FACTOR * @as(f32, @floatFromInt(elapsed_days)) / stability, 
        Parameters.DECAY
    );
    // zig fmt: on
}

fn meanReversion(self: Self, initial: f32, current: f32) f32 {
    // zig fmt: off
    return @mulAdd(
        f32, 
        self.params.w[7], 
        initial, 
        (1.0 - self.params.w[7]) * current
    );
    // zig fmt: on
}

fn nextInterval(self: Self, stability: f32) i64 {
    // zig fmt: off
    const next_interval = @as(i32, 
        @intFromFloat(@round(
            stability / Parameters.FACTOR 
            * (std.math.pow(
                f32, 
                self.params.request_retention, 
                1.0 / Parameters.DECAY)
            - 1.0)
        ))
    );
    // zig fmt: on

    return @max(1, @min(self.params.maximum_interval, next_interval));
}

fn nextForgetStability(self: Self, card: *const Card) f32 {
    const retrievability = forgettingCurve(card.elapsed_days, card.stability);
    // zig fmt: off
    return self.params.w[11] 
        * std.math.pow(f32, card.difficulty, -self.params.w[12]) 
        * (std.math.pow(f32, card.stability + 1.0, self.params.w[13]) - 1.0) 
        * std.math.exp((1.0 - retrievability) * self.params.w[14]);
    // zig fmt: on
}

fn nextRecallStability(self: Self, card: *const Card, rating: Rating) f32 {
    const modifier = switch (rating) {
        .Hard => self.params.w[15],
        .Easy => self.params.w[16],
        else => 1.0,
    };

    const retrievability = forgettingCurve(card.elapsed_days, card.stability);
    // zig fmt: off
    return card.stability 
        * @mulAdd(f32, 
            std.math.exp(self.params.w[8]) 
            * (11.0 - card.difficulty) 
            * std.math.pow(f32, card.stability, -self.params.w[9]) 
            * std.math.expm1((1.0 - retrievability) * self.params.w[10]), 
        modifier, 1.0);
    // zig fmt: on
}

fn nextDifficulty(self: Self, card: *const Card, rating: Rating) f32 {
    // zig fmt: off
    const difficulty = @mulAdd(
        f32, 
        self.params.w[6],
        -(@as(f32, @floatFromInt(@intFromEnum(rating))) - 3.0),
        card.difficulty
    );
    // zig fmt: on

    return @min(10.0, @max(1.0, self.meanReversion(self.params.w[4], difficulty)));
}
