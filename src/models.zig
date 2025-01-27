const std = @import("std");

pub const State = enum(u2) {
    New = 0,
    Learning = 1,
    Review = 2,
    Relearning = 3,

    pub fn format(
        self: State,
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try writer.writeAll(@tagName(self));
    }
};

pub const Rating = enum(u3) {
    Again = 1,
    Hard = 2,
    Good = 3,
    Easy = 4,

    pub fn format(
        self: Rating,
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try writer.writeAll(@tagName(self));
    }
};

pub const Parameters = struct {
    pub const DECAY: f32 = -0.5;
    pub const FACTOR: f32 = 19.0 / 81.0;

    request_retention: f32 = 0.9,
    maximum_interval: i32 = 36500,
    w: [17]f32 = [17]f32{ 0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755 },
};

pub const ReviewLog = struct {
    rating: Rating,
    elapsed_days: i64,
    scheduled_days: i64,
    state: State,
    reviewed_date: i64,
};

pub const ReviewedCard = struct {
    card: Card,
    review_log: ReviewLog,
};

pub const Card = struct {
    state: State,
    reps: i32,
    lapses: i32,
    stability: f32,
    difficulty: f32,
    elapsed_days: i64,
    scheduled_days: i64,
    due: i64,
    last_review: i64,

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
        };
    }

    pub fn format(
        self: Card,
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try writer.print(
            \\  state:          {any}
            \\  reps:           {d}
            \\  lapses:         {d}
            \\  stability:      {d}
            \\  difficulty:     {d}
            \\  elapsed days:   {d}
            \\  scheduled days: {d}
            \\  due:            {d}
            \\  last review:    {d}
        , self);
    }
};

pub const ScheduledCards = struct {
    again: ReviewedCard,
    hard: ReviewedCard,
    good: ReviewedCard,
    easy: ReviewedCard,

    const Self = @This();

    pub fn select(self: Self, rating: Rating) ReviewedCard {
        return switch (rating) {
            .Again => self.again,
            .Hard => self.hard,
            .Good => self.good,
            .Easy => self.easy,
        };
    }
};

pub const SchedulingCards = struct {
    again: Card,
    hard: Card,
    good: Card,
    easy: Card,

    const Self = @This();

    pub fn init(card: *const Card) Self {
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

    pub fn toScheduledCards(self: Self, now: i64) ScheduledCards {
        return .{
            .again = .{
                .card = self.again,
                .review_log = .{
                    .rating = .Again,
                    .elapsed_days = self.again.elapsed_days,
                    .scheduled_days = self.again.scheduled_days,
                    .state = self.again.state,
                    .reviewed_date = now,
                },
            },
            .hard = .{
                .card = self.hard,
                .review_log = .{
                    .rating = .Hard,
                    .elapsed_days = self.hard.elapsed_days,
                    .scheduled_days = self.hard.scheduled_days,
                    .state = self.hard.state,
                    .reviewed_date = now,
                },
            },
            .good = .{
                .card = self.good,
                .review_log = .{
                    .rating = .Good,
                    .elapsed_days = self.good.elapsed_days,
                    .scheduled_days = self.good.scheduled_days,
                    .state = self.good.state,
                    .reviewed_date = now,
                },
            },
            .easy = .{
                .card = self.easy,
                .review_log = .{
                    .rating = .Easy,
                    .elapsed_days = self.easy.elapsed_days,
                    .scheduled_days = self.easy.scheduled_days,
                    .state = self.easy.state,
                    .reviewed_date = now,
                },
            },
        };
    }
};
