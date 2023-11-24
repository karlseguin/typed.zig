# Typed.zig

A tagged union type that can represent many different types. Similar to `std.json.Value`, but supports more types and has more functionality.

## typed.Value
`typed.Value` is a union defined with the following tags:

```zig
    null,
    bool: bool,
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    u128: u128,
    f32: f32,
    f64: f64,
    string: []const u8,
    map: typed.Map,
    array: typed.Array,
    time: typed.Time,
    date: typed.Date,
    timestamp: typed.Timestamp,
```

There are a number of ways to create a `typed.Value`:

```zig
const v1 = typed.Value{.i64 = 9001};
defer v1.deinit(); // safe to call even for non-allocating types

// Values that map to a typed.Array or typed.Map require allocation
const v2 = try typed.new(allocator, [_]bool{true, false});
defer v2.deinit();

// or created from an optional std.json.Value
const v3 = try typed.fromJson(allocator, json_value);
defer v3.deinit();
```

`typed.new` will map arrays and slices to `typed.Array` which is an alias for `std.ArrayList(typed.Value)`. This requires allocation.

`typed.new` will map structs to a `typed.Map` which is a wrapper around `std.StringHashMap(typed.Value)`. This requires allocation.

It is always safe to call `deinit()` on a value, even if the underlying value required no allocations.

You can, of course, access the underlying value by accessing the tag, e.g. `const power = value.i64`. Alternatively, `value.get(TYPE)` can be used to conditionally get a value. If `TYPE` is the wrong type, `null` is returned. `value.strictGet(TYPE)` will return an error if `TYPE` is wrong.
