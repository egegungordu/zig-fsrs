# zig-fsrs

This is an implementation of [FSRS-4.5](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm) in Zig.  
This project is on zig 0.13.0

```zig
const std = @import("std");
const fsrs = @import("zig-fsrs");
const Card = fsrs.Card;

pub fn main() !void {
    var f = fsrs.FSRS.init(.{});
    const initial_card = fsrs.Card.init();
    var now = std.time.timestamp();

    // schedule the initial card
    var s = f.schedule(initial_card, now);

    // good was selected on new card
    const updated_card = s.select(.Good).card;

    std.debug.print("initial card:\n{}\n\n", .{initial_card});
    std.debug.print("after first rep (good):\n{}\n\n", .{updated_card});
}
```

## Getting Started

### 1. Add zig-fsrs to your own zig project:

Fetch zig-fsrs:

```shell
zig fetch --save git+https://github.com/egegungordu/zig-fsrs
```

### 2. Add zig-fsrs to your `build.zig` file:

```zig
const zig_fsrs = b.dependency("zig-fsrs", .{});
exe.root_module.addImport("zig-fsrs", zig_fsrs.module("zig-fsrs"));
```

Now you can import zig-fsrs in your code:

```zig
const fsrs = @import("zig-fsrs");
```

## Basic Usage

### 1. Create a new FSRS instance

```zig
var f = fsrs.FSRS.init(.{});
```

The parameters are optional. The parameters are:

| Parameter         | Type    | Default Value                                                                                                                             |
| ----------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| request_retention | f32     | 0.9                                                                                                                                       |
| maximum_interval  | i32     | 36500                                                                                                                                     |
| w                 | [17]f32 | { 0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755 } |

### 2. Create a new card

```zig
const initial_card = fsrs.Card.init();
```

### 3. Schedule the card

```zig
const review_time = std.time.timestamp();
var scheduled_cards = f.schedule(initial_card, review_time);
```

`schedule()` will return a `ScheduledCards` struct which contains the possible
cards given the rating. To select a card, use the `select` method, which
will return a `ReviewedCard` struct.

```zig
const good = scheduled_cards.select(.Good);
const new_card = good.card;
```

### Card fields

| Field          | Type  | Description                                                                 |
| -------------- | ----- | --------------------------------------------------------------------------- |
| state          | State | The state of the card. Can be `New`, `Learning`, `Review`, or `Relearning`. |
| reps           | i32   | The number of repetitions of the card.                                      |
| lapses         | i32   | The number of times the card was remembered incorrectly.                    |
| stability      | f32   | A measure of how well the card is remembered.                               |
| difficulty     | f32   | The inherent difficulty of the card content.                                |
| elapsed_days   | i64   | The number of elapsed days since the card was last reviewed.                |
| scheduled_days | i64   | The next scheduled days for the card.                                       |
| due            | i64   | The due date for the next review.                                           |
| last_review    | i64   | The last review date of the card.                                           |

## Examples

To run the examples:

```shell
zig build example -Dexample=example_name
```

Check out the [examples](examples) directory for more examples.

## Development

```shell
git clone https://github.com/egegungordu/zig-fsrs.git
cd zig-fsrs
```

To run the tests:

```shell
zig build test --summary all
```
