const std = @import("std");
const fmt = std.fmt;
const heap = std.heap;
const mem = std.mem;
const meta = std.meta;

const fsrs = @import("zig-fsrs");
const vaxis = @import("vaxis");

const log = std.log.scoped(.main);

const TableItem = struct {
    index: usize,
    due: i64,
    state: fsrs.State,
    last_review: i64,
    stability: f32,
    difficulty: f32,
    elapsed_days: i64,
    scheduled_days: i64,
    reps: i64,
    lapses: i64,

    fn fromCardWithIndex(card: fsrs.Card, index: usize) TableItem {
        return TableItem{
            .index = index,
            .due = card.due,
            .state = card.state,
            .last_review = card.last_review,
            .stability = card.stability,
            .difficulty = card.difficulty,
            .elapsed_days = card.elapsed_days,
            .scheduled_days = card.scheduled_days,
            .reps = card.reps,
            .lapses = card.lapses,
        };
    }
};

fn handleRateCard(f: *fsrs.FSRS, card_history: *std.ArrayList(fsrs.Card), table_list: *std.ArrayList(TableItem), rating: fsrs.Rating) !void {
    const last_card = card_history.getLast();
    const s = f.schedule(last_card, last_card.due);
    const new_card = s.select(rating).card;
    try card_history.append(new_card);
    try table_list.append(TableItem.fromCardWithIndex(new_card, table_list.items.len));
}

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.detectLeaks()) log.err("Memory leak detected!", .{});
    const alloc = gpa.allocator();

    var card_history = std.ArrayList(fsrs.Card).init(alloc);
    const init_card = fsrs.Card.init();
    try card_history.append(init_card);
    defer card_history.deinit();

    var table_list = std.ArrayList(TableItem).init(alloc);
    try table_list.append(TableItem.fromCardWithIndex(init_card, 0));
    defer table_list.deinit();

    var tty = try vaxis.Tty.init();
    defer tty.deinit();

    var vx = try vaxis.init(alloc, .{});
    defer vx.deinit(alloc, tty.anyWriter());

    var f = fsrs.FSRS.init(.{});

    var loop: vaxis.Loop(union(enum) {
        key_press: vaxis.Key,
        winsize: vaxis.Winsize,
    }) = .{ .tty = &tty, .vaxis = &vx };

    try loop.start();
    defer loop.stop();
    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminal(tty.anyWriter(), 1 * std.time.ns_per_s);

    // Colors
    const selected_bg: vaxis.Cell.Color = .{ .rgb = .{ 64, 128, 255 } };
    const other_bg: vaxis.Cell.Color = .{ .rgb = .{ 32, 32, 48 } };

    const title_logo = vaxis.Cell.Segment{
        .text = "zig-fsrs\n",
        .style = .{
            .bg = other_bg,
        },
    };
    const title_info = vaxis.Cell.Segment{
        .text = "Press 1-4 to rate the card.\n",
        .style = .{
            .bg = other_bg,
        },
    };
    const title_ratings = vaxis.Cell.Segment{
        .text = "1: Again  2: Hard  3: Good  4: Easy\n",
        .style = .{
            .fg = .{ .rgb = .{ 255, 255, 255 } },
            .bg = .{ .rgb = .{ 0, 0, 0 } },
        },
    };
    var title_segs = [_]vaxis.Cell.Segment{ title_logo, title_info, title_ratings };

    var keys = [_]vaxis.Cell.Segment{.{
        .text = "k: up\nj: down\nh: left\nl: right\nctrl + C: exit",
        .style = .{
            .fg = .{ .rgb = .{ 128, 128, 128 } },
            .bg = other_bg,
        },
    }};

    // Table Context
    var demo_tbl: vaxis.widgets.Table.TableContext = .{ .selected_bg = selected_bg };

    while (true) {
        // Create an Arena Allocator for easy allocations on each Event.
        var event_arena = heap.ArenaAllocator.init(alloc);
        defer event_arena.deinit();
        const event_alloc = event_arena.allocator();
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| {
                // Close the Program
                if (key.matches('c', .{ .ctrl = true })) {
                    break;
                }

                if (key.matches('1', .{})) {
                    try handleRateCard(&f, &card_history, &table_list, .Again);
                    demo_tbl.row = card_history.items.len - 1;
                }

                if (key.matches('2', .{})) {
                    try handleRateCard(&f, &card_history, &table_list, .Hard);
                    demo_tbl.row = card_history.items.len - 1;
                }

                if (key.matches('3', .{})) {
                    try handleRateCard(&f, &card_history, &table_list, .Good);
                    demo_tbl.row = card_history.items.len - 1;
                }

                if (key.matches('4', .{})) {
                    try handleRateCard(&f, &card_history, &table_list, .Easy);
                    demo_tbl.row = card_history.items.len - 1;
                }

                // Change Row
                if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{})) demo_tbl.row -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{})) demo_tbl.row +|= 1;
                // Change Column
                if (key.matchesAny(&.{ vaxis.Key.left, 'h' }, .{})) demo_tbl.col -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.right, 'l' }, .{})) demo_tbl.col +|= 1;
            },
            .winsize => |ws| try vx.resize(alloc, tty.anyWriter(), ws),
            //else => {},
        }

        // Sections
        // - Window
        const win = vx.window();
        win.clear();

        // - Top left
        const top_left_bar = win.initChild(
            0,
            0,
            .{ .limit = win.width / 3 },
            .{ .limit = 5 },
        );
        top_left_bar.fill(.{ .style = .{
            .bg = other_bg,
        } });
        _ = try top_left_bar.print(keys[0..], .{ .wrap = .word });

        // - Top middle
        const top_middle_bar = win.initChild(
            win.width / 3,
            0,
            .{ .limit = win.width / 3 },
            .{ .limit = 5 },
        );
        top_middle_bar.fill(.{ .style = .{
            .bg = other_bg,
        } });
        const logo_bar = vaxis.widgets.alignment.center(top_middle_bar, 42, 3);
        _ = try logo_bar.print(title_segs[0..], .{ .wrap = .word });

        // - Top right
        const top_right_bar = win.initChild(
            win.width / 3 * 2,
            0,
            .{ .limit = win.width / 3 },
            .{ .limit = 5 },
        );
        top_right_bar.fill(.{ .style = .{
            .bg = other_bg,
        } });

        // - Middle
        const middle_bar = win.initChild(
            0,
            5,
            .{ .limit = win.width },
            .{ .limit = win.height - top_middle_bar.height },
        );

        if (card_history.items.len > 0) {
            demo_tbl.active = true;
            try vaxis.widgets.Table.drawTable(
                event_alloc,
                middle_bar,
                &.{ "index", "due", "state", "last review", "stability", "difficulty", "elapsed days", "scheduled days", "reps", "lapses" },
                table_list,
                &demo_tbl,
            );
        }

        // Render the screen
        try vx.render(tty.anyWriter());
    }
}
