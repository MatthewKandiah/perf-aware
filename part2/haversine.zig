const std = @import("std");
const math = std.math;

pub const EARTH_RADIUS_KM = 6372.8;

fn square(x: f64) f64 {
    return x * x;
}

pub fn radiansFromDegrees(degrees: f64) f64 {
    return 0.01745329251994329577 * degrees;
}

pub fn haversine(x0: f64, y0: f64, x1: f64, y1: f64, radius: f64) f64 {
    const d_lat = radiansFromDegrees(y1 - y0);
    const d_lon = radiansFromDegrees(x1 - x0);
    const lat1 = radiansFromDegrees(y0);
    const lat2 = radiansFromDegrees(y1);

    const a = square(@sin(d_lat / 2)) + @cos(lat1) * @cos(lat2) * square(@sin(d_lon / 2));
    const c = 2 * math.asin(math.sqrt(a));
    return radius * c;
}
