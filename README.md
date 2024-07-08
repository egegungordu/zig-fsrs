# zig-fsrs

This is an implementation of [FSRS-4.5](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm) in Zig.  
This project is on zig 0.13.0

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


