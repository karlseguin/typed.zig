Thin (and maybe useless) Wrapper Around std.json.ValueTree

This library is a very thin wrapper around std.json.ValueTree with the goal of providing a slightly more user-friendly API, especially in the face of questionable input (e.g. user-input).

# Installation
This library supports native Zig module (introduced in 0.11). Add a "typed" dependency to your `build.zig.zon`.

# Usage
```zig
const typed = @import("typed");
...
// See the 'Copy' second for details on the 3rd parameter
const obj = typed.fromJson(allocator, "{\"power\": {\"over\": 9001}}, false);
defer obj.deinit();
obj.object("power").?.int("over").? // 9001
```

What this offers over `std.json.ValueTree` is that missing keys or wrong types return `null`, essentially making it easier to deal with invalid data:

```zig
// similar to above, but more defensive
obj.object("power").?.int("over") orelse 0;
```

The `Typed` object exposes a: `int`, `boolean`, `float`, `string`, `object` and `array` function. Each returns an optional value.

## Arrays
`std.json.ValueTree.Array` is an `std.ArrayList(std.json.Value)`. This cannot be converted to an `std.ArrayList(Typed)` without additional memory allocation. Therefore, arrays have a slightly awkward API:`

```zig
// given an array of ints
var sum: i64 = 0;
const values = obj.array("values") orelse return;
for (values.items) |value| {
    sum += typed.int(value) orelse 0;
}
```

The `typed` package itself exposes the same functions as the `Typed` type, namely: `int`, `boolean`, `float`, `string`, `object` and `array`.

So given an array of objects, we can do:

```zig
// given an array of objects such as: {"count": INT}
var total: i64 = 0;
const values = obj.array("values") orelse return;
for (values.items) |value| {
    const child = typed.object(value) orelse continue;
    total += child.int("count") orelse 0;
}
```

## Copy
`fromJson` merely calls `std.json.Parser.init(allocator, copy)`. The `copy` parameter tells `json.Parser` if it should create a copy of the data. Essentially, copy should be true if the Typed object outlives the input data (or if the input data is mutated after).
