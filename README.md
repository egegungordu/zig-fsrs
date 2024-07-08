# zig-fsrs

This is an implementation of [FSRS-4.5](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm) in Zig.  
This project is on zig 0.13.0

```zig
const std = @import("std");
const fsrs = @import("zig-fsrs");

pub fn main() !void {
    var fsrs = fsrs.FSRS.init(.{});
    const initial_card = fsrs.Card.init();
    var now = std.time.timestamp();
    var s = fsrs.repeat(initial_card, now);

    // good was selected on new card
    const first_rep = s[@intFromEnum(Rating.Good) - 1].card;
    now = first_rep.due;

    // good was selected on learning card
    s = fsrs.repeat(first_rep, now);
    const second_rep = s[@intFromEnum(Rating.Good) - 1].card;
    now = second_rep.due;

    // again was selected on review card
    s = fsrs.repeat(second_rep, now);
    const third_rep = s[@intFromEnum(Rating.Again) - 1].card;
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
```

## Getting Started

```shell
git clone https://github.com/egegungordu/zig-fsrs.git
cd zig-fsrs
zig build test --summary all
```

If you want to include zig-fsrs in your own zig project:

Fetch zig-fsrs:

```shell
zig fetch --save git+https://github.com/egegungordu/zig-fsrs
```

Add zig-fsrs to your `build.zig` file:

```zig
const zig_fsrs = b.dependency("zig-fsrs", .{});
exe.root_module.addImport("zig-fsrs", zig_fractions.module("zig-fsrs"));
```

Now you can import zig-fsrs in your code:

```zig
const fsrs = @import("zig-fsrs");
```

## Usage


