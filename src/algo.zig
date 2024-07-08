const std = @import("std");

const Models = @import("models.zig");
const Parameters = Models.Parameters;
const Card = Models.Card;
const SchedulingCards = Models.SchedulingCards;
const SchedulingInfo = Models.SchedulingInfo;
const Rating = Models.Rating;

const Self = @This();

params: Parameters,

pub fn init(params: Parameters) Self {
    return .{
        .params = params,
    };
}

pub fn repeat(self: *Self, card: *Card, now: i64) [Rating._len]SchedulingInfo {
    const minute = 60;
    const day = 24 * 60 * 60;

    if (card.state == .New) {
        card.elapsed_days = 0;
    } else {
        card.elapsed_days = @divFloor(now - card.last_review, day);
    }
    card.last_review = now;
    card.reps += 1;
    var s = SchedulingCards.init(card);
    s.updateState(card.state);

    switch (card.state) {
        .New => {
            self.initDifficultyStability(&s);

            const easy_interval = self.getNextInterval(s.easy.stability);

            s.again.due = now + 1 * minute;
            s.hard.due = now + 5 * minute;
            s.good.due = now + 10 * minute;
            s.easy.scheduled_days = easy_interval;
            s.easy.due = now + easy_interval * day;
        },
        .Learning, .Relearning => {
            const good_interval = self.getNextInterval(s.good.stability);
            const easy_interval = @max(good_interval + 1, self.getNextInterval(s.easy.stability));

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
            self.setNextDifficultyStability(&s, card);

            // TODO: might be better to use a function that gets all
            // the needed variables
            // calculateNextInterval
            //   - max_interval
            //   - request_retention
            //   - stability
            //   - difficulty
            //   - factor
            //   - decay
            //
            //  and then call it with getNextInterval
            var hard_interval = self.getNextInterval(s.hard.stability);
            var good_interval = self.getNextInterval(s.good.stability);
            var easy_interval = self.getNextInterval(s.easy.stability);

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

    return s.recordLog(now);
}

// max(w_(rating - 1), 0.1)
fn initStability(self: *Self, rating: Rating) f32 {
    return @max(self.params.w[@intFromEnum(rating) - 1], 0.1);
}

// w_4 - (G - 3) * w_5
fn initDifficulty(self: *Self, rating: Rating) f32 {
    return @min(10, @max(1, @mulAdd(f32, self.params.w[5], -(@as(f32, @floatFromInt(@intFromEnum(rating))) - 3.0), self.params.w[4])));
}

fn initDifficultyStability(self: *Self, scheduling_cards: *SchedulingCards) void {
    scheduling_cards.again.stability = self.initStability(.Again);
    scheduling_cards.again.difficulty = self.initDifficulty(.Again);
    scheduling_cards.hard.stability = self.initStability(.Hard);
    scheduling_cards.hard.difficulty = self.initDifficulty(.Hard);
    scheduling_cards.good.stability = self.initStability(.Good);
    scheduling_cards.good.difficulty = self.initDifficulty(.Good);
    scheduling_cards.easy.stability = self.initStability(.Easy);
    scheduling_cards.easy.difficulty = self.initDifficulty(.Easy);
}

fn forgettingCurve(elapsed_days: i64, stability: f32) f32 {
    return std.math.pow(f32, 1.0 + Parameters.FACTOR * @as(f32, @floatFromInt(elapsed_days)) / stability, Parameters.DECAY);
}

fn getMeanReversion(self: *Self, initial: f32, current: f32) f32 {
    return @mulAdd(f32, self.params.w[7], initial, (1.0 - self.params.w[7]) * current);
}

fn getNextInterval(self: *Self, stability: f32) i64 {
    return @max(1, @min(self.params.maximum_interval, @as(i32, @intFromFloat(@round(stability / Parameters.FACTOR * (std.math.pow(f32, self.params.request_retention, 1.0 / Parameters.DECAY) - 1.0))))));
}

fn getNextForgetStability(self: *Self, card: *Card) f32 {
    const retrievability = forgettingCurve(card.elapsed_days, card.stability);
    // zig fmt: off
    return self.params.w[11] 
        * std.math.pow(f32, card.difficulty, -self.params.w[12]) 
        * (std.math.pow(f32, card.stability + 1.0, self.params.w[13]) - 1.0) 
        * std.math.exp((1.0 - retrievability) * self.params.w[14]);
    // zig fmt: on
}

fn getNextRecallStability(self: *Self, card: *Card, rating: Rating) f32 {
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

fn getNextDifficulty(self: *Self, card: *Card, rating: Rating) f32 {
    const difficulty = @mulAdd(f32, self.params.w[6], -(@as(f32, @floatFromInt(@intFromEnum(rating))) - 3.0), card.difficulty);
    return @min(10.0, @max(1.0, self.getMeanReversion(self.params.w[4], difficulty)));
}

fn setNextDifficultyStability(self: *Self, scheduling_cards: *SchedulingCards, last_card: *Card) void {
    scheduling_cards.again.stability = self.getNextForgetStability(last_card);
    scheduling_cards.again.difficulty = self.getNextDifficulty(last_card, .Again);
    scheduling_cards.hard.stability = self.getNextRecallStability(last_card, .Hard);
    scheduling_cards.hard.difficulty = self.getNextDifficulty(last_card, .Hard);
    scheduling_cards.good.stability = self.getNextRecallStability(last_card, .Good);
    scheduling_cards.good.difficulty = self.getNextDifficulty(last_card, .Good);
    scheduling_cards.easy.stability = self.getNextRecallStability(last_card, .Easy);
    scheduling_cards.easy.difficulty = self.getNextDifficulty(last_card, .Easy);
}
