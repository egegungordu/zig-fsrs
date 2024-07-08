const std = @import("std");

pub const State = enum(u2) {
    New = 0,
    Learning = 1,
    Review = 2,
    Relearning = 3,
};

pub const Rating = enum(u3) {
    Manual = 0,
    Again = 1,
    Hard = 2,
    Good = 3,
    Easy = 4,

    pub const _len = @typeInfo(Rating).Enum.fields.len - 1;
};

// pub const RATINGS_LEN = @typeInfo(Rating).Enum.fields.len;

pub const Parameters = struct {
    pub const DECAY: f32 = -0.5;
    pub const FACTOR: f32 = 19.0 / 81.0;

    request_retention: f32 = 0.9,
    maximum_interval: i32 = 36500,
    w: [17]f32 = [17]f32{ 0.5701, 1.4436, 4.1386, 10.9355, 5.1443, 1.2006, 0.8627, 0.0362, 1.629, 0.1342, 1.0166, 2.1174, 0.0839, 0.3204, 1.4676, 0.219, 2.8237 },
};

pub const ReviewLog = struct {
    rating: Rating,
    elapsed_days: i64,
    scheduled_days: i64,
    state: State,
    reviewed_date: i64,
};

pub const SchedulingInfo = struct {
    card: Card,
    review_log: ReviewLog,
};

pub const Card = struct {
    due: i64,
    stability: f32,
    difficulty: f32,
    elapsed_days: i64,
    scheduled_days: i64,
    reps: i32,
    lapses: i32,
    state: State,
    last_review: i64,
    previous_state: State,

    pub fn init() Card {
        return .{
            .due = std.time.timestamp(),
            .stability = 0,
            .difficulty = 0,
            .elapsed_days = 0,
            .scheduled_days = 0,
            .reps = 0,
            .lapses = 0,
            .state = .New,
            .last_review = 0,
            .previous_state = .New,
        };
    }
};

pub const SchedulingCards = struct {
    again: Card,
    hard: Card,
    good: Card,
    easy: Card,

    const Self = @This();

    pub fn init(card: *Card) Self {
        return .{
            .again = card.*,
            .hard = card.*,
            .good = card.*,
            .easy = card.*,
        };
    }

    pub fn updateState(self: *Self, state: State) void {
        switch (state) {
            .New => {
                self.again.state = .Learning;
                self.hard.state = .Learning;
                self.good.state = .Learning;
                self.easy.state = .Review;
            },
            .Learning, .Relearning => {
                self.again.state = state;
                self.hard.state = state;
                self.good.state = .Review;
                self.easy.state = .Review;
            },
            .Review => {
                self.again.state = .Relearning;
                self.hard.state = .Review;
                self.good.state = .Review;
                self.easy.state = .Review;
                self.again.lapses += 1;
            },
        }
    }

    // pub fn schedule(self: *Self, now: i64, hard_interval: i64, good_interval: i64, easy_interval: i64) *Self {
    //     self.again.scheduled_days = 0;
    //     self.hard.scheduled_days = hard_interval;
    //     self.good.scheduled_days = good_interval;
    //     self.easy.scheduled_days = easy_interval;
    //     if (hard_interval > 0) {
    //         // add n days
    //         self.hard.due = now + hard_interval * 24 * 60 * 60;
    //     } else {
    //         // add 10 minutes
    //         self.hard.due = now + 10 * 60;
    //     }
    //     // add n days
    //     self.good.due = now + good_interval * 24 * 60 * 60;
    //     self.easy.due = now + easy_interval * 24 * 60 * 60;
    //
    //     return self;
    // }

    pub fn recordLog(self: *Self, now: i64) [Rating._len]SchedulingInfo {
        return [Rating._len]SchedulingInfo{ .{
            .card = self.again,
            .review_log = .{
                .rating = .Again,
                .elapsed_days = self.again.elapsed_days,
                .scheduled_days = self.again.scheduled_days,
                .state = self.again.state,
                .reviewed_date = now,
            },
        }, .{
            .card = self.hard,
            .review_log = .{
                .rating = .Hard,
                .elapsed_days = self.hard.elapsed_days,
                .scheduled_days = self.hard.scheduled_days,
                .state = self.hard.state,
                .reviewed_date = now,
            },
        }, .{
            .card = self.good,
            .review_log = .{
                .rating = .Good,
                .elapsed_days = self.good.elapsed_days,
                .scheduled_days = self.good.scheduled_days,
                .state = self.good.state,
                .reviewed_date = now,
            },
        }, .{
            .card = self.easy,
            .review_log = .{
                .rating = .Easy,
                .elapsed_days = self.easy.elapsed_days,
                .scheduled_days = self.easy.scheduled_days,
                .state = self.easy.state,
                .reviewed_date = now,
            },
        } };
    }
};
