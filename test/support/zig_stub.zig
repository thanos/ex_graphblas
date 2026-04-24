const beam = @import("beam");

pub fn add_one(number: i64) i64 {
    return number + 1;
}

pub fn ping() beam.term {
    return beam.make(:ok, .{});
}
