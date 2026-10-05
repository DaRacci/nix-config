//! Software rasterisation for the overlay buffers.

/// Half-width of the supersampled edge band, in pixels.
///
/// A pixel is only evaluated once when its centre is at least this far from both the fill/border and border/transparent boundaries.
/// The four supersamples sit at most `sqrt(0.25^2 + 0.25^2) ~= 0.354px` from the centre in Euclidean distance, so `1.0` is a safe margin.
const AA_BAND: f32 = 1.0;

/// Straight **RGBA** rendered as premultiplied **BGRA** into a `wl_shm::Format::Argb8888` buffer.
///
/// Only pixels inside the ~[`AA_BAND`]px band around an edge are anti-aliased with 2x2 supersampling.
pub fn paint(
    canvas: &mut [u8],
    width: u32,
    height: u32,
    fill: [u8; 4],
    border: [u8; 4],
    border_width: i32,
    rounding: i32,
) {
    let half_w = width as f32 / 2.0;
    let half_h = height as f32 / 2.0;
    let radius = (rounding.max(0) as f32).min(half_w).min(half_h);
    let border_width = border_width.max(0) as f32;

    let fill_f = premultiply(to_f32(fill));
    let border_f = premultiply(to_f32(border));
    let samples = [
        (-0.25f32, -0.25f32),
        (0.25, -0.25),
        (-0.25, 0.25),
        (0.25, 0.25),
    ];
    let inv = 1.0 / samples.len() as f32;

    // Pixels whose centre distance is at or below this are fully inside the fill region
    let inner = -(border_width + AA_BAND);

    for y in 0..height {
        for x in 0..width {
            let index = ((y * width + x) * 4) as usize;
            let px = (x as f32 + 0.5) - half_w;
            let py = (y as f32 + 0.5) - half_h;
            let distance = rounded_box_distance(px, py, half_w, half_h, radius);

            // Solid interior with no edge nearby, so write the premultiplied fill directly.
            if distance <= inner {
                write_premultiplied(&mut canvas[index..index + 4], fill_f);
                continue;
            }

            // Fully outside, need to clear it.
            // The SHM buffer may be recycled, so every pixel must be written even when the result is transparent.
            if distance >= AA_BAND {
                canvas[index..index + 4].fill(0);
                continue;
            }

            // 2x2 supersampled coverage across the fill/border and border/transparent boundaries.
            let mut acc = [0.0f32; 4];
            for (sx, sy) in samples {
                let d = rounded_box_distance(px + sx, py + sy, half_w, half_h, radius);
                let (r, g, b, a) = if d <= -border_width {
                    (fill_f[0], fill_f[1], fill_f[2], fill_f[3])
                } else if d <= 0.0 {
                    (border_f[0], border_f[1], border_f[2], border_f[3])
                } else {
                    (0.0, 0.0, 0.0, 0.0)
                };

                acc[0] += r;
                acc[1] += g;
                acc[2] += b;
                acc[3] += a;
            }

            canvas[index] = to_u8(acc[2] * inv);
            canvas[index + 1] = to_u8(acc[1] * inv);
            canvas[index + 2] = to_u8(acc[0] * inv);
            canvas[index + 3] = to_u8(acc[3] * inv);
        }
    }
}

fn rounded_box_distance(px: f32, py: f32, half_w: f32, half_h: f32, radius: f32) -> f32 {
    let qx = px.abs() - (half_w - radius);
    let qy = py.abs() - (half_h - radius);
    let outside = (qx.max(0.0).powi(2) + qy.max(0.0).powi(2)).sqrt();
    outside + qx.max(qy).min(0.0) - radius
}

fn premultiply(color: [f32; 4]) -> [f32; 4] {
    let a = color[3];
    [color[0] * a, color[1] * a, color[2] * a, a]
}

/// Write a premultiplied RGBA float colour as little-endian BGRA bytes.
fn write_premultiplied(out: &mut [u8], color: [f32; 4]) {
    out[0] = to_u8(color[2]);
    out[1] = to_u8(color[1]);
    out[2] = to_u8(color[0]);
    out[3] = to_u8(color[3]);
}

fn to_u8(value: f32) -> u8 {
    value.clamp(0.0, 1.0).mul_add(255.0, 0.5) as u8
}

fn to_f32(color: [u8; 4]) -> [f32; 4] {
    [
        color[0] as f32 / 255.0,
        color[1] as f32 / 255.0,
        color[2] as f32 / 255.0,
        color[3] as f32 / 255.0,
    ]
}

/// Parse `RRGGBB` or `RRGGBBAA` into straight **RGBA** bytes, matching the channel order [`paint`] expects.
/// `paint` premultiplies and writes BGRA when compositing, so colours must not be premultiplied here.
pub(crate) fn parse_hex(value: &str) -> [u8; 4] {
    let value = value.trim().trim_start_matches('#');
    let parse = |range: std::ops::Range<usize>| {
        u8::from_str_radix(value.get(range).unwrap_or("00"), 16).unwrap_or(0)
    };

    let r = parse(0..2);
    let g = parse(2..4);
    let b = parse(4..6);
    let a = if value.len() >= 8 { parse(6..8) } else { 0xff };

    [r, g, b, a]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pixel(canvas: &[u8], width: u32, x: u32, y: u32) -> [u8; 4] {
        let index = ((y * width + x) * 4) as usize;
        [
            canvas[index],
            canvas[index + 1],
            canvas[index + 2],
            canvas[index + 3],
        ]
    }

    #[test]
    fn interior_is_opaque_fill() {
        let (w, h) = (100, 100);
        let mut canvas = vec![0u8; (w * h * 4) as usize];
        // Input is straight RGBA, output is BGRA bytes; alpha 255 means no premultiply shift.
        paint(&mut canvas, w, h, [10, 20, 30, 255], [0, 0, 0, 0], 2, 0);
        assert_eq!(pixel(&canvas, w, 50, 50), [30, 20, 10, 255]);
    }

    #[test]
    fn interior_is_premultiplied() {
        let (w, h) = (100, 100);
        let mut canvas = vec![0u8; (w * h * 4) as usize];
        // Straight fill R=100, G=50, B=200, A=128 -> BGRA bytes, each channel premultiplied.
        paint(&mut canvas, w, h, [100, 50, 200, 128], [0, 0, 0, 0], 2, 0);
        let [b, g, r, a] = pixel(&canvas, w, 50, 50);
        assert_eq!(a, 128);
        assert_eq!(b, (200.0f32 * 128.0 / 255.0).round() as u8);
        assert_eq!(g, (50.0f32 * 128.0 / 255.0).round() as u8);
        assert_eq!(r, (100.0f32 * 128.0 / 255.0).round() as u8);
    }

    #[test]
    fn outside_rounded_corner_is_transparent() {
        let (w, h) = (100, 100);
        let mut canvas = vec![0xffu8; (w * h * 4) as usize];
        paint(&mut canvas, w, h, [10, 20, 30, 255], [0, 0, 0, 0], 2, 20);
        // The top-left pixel sits well outside the 20px corner arc.
        assert_eq!(pixel(&canvas, w, 0, 0), [0, 0, 0, 0]);
    }

    #[test]
    fn border_ring_is_border_colour() {
        let (w, h) = (100, 100);
        let mut canvas = vec![0u8; (w * h * 4) as usize];
        // Straight border R=60, G=70, B=80 -> BGRA bytes [80, 70, 60].
        paint(
            &mut canvas,
            w,
            h,
            [10, 20, 30, 255],
            [60, 70, 80, 255],
            3,
            0,
        );
        // x=1 is within the 3px border ring on the left edge.
        assert_eq!(pixel(&canvas, w, 1, 50), [80, 70, 60, 255]);
    }

    #[test]
    fn hex_colours_survive_the_pixel_format_round_trip() {
        let (w, h) = (64, 64);
        let mut canvas = vec![0u8; (w * h * 4) as usize];
        paint(
            &mut canvas,
            w,
            h,
            parse_hex("7dcfff"),
            parse_hex("bb9af7"),
            3,
            8,
        );

        let [b, g, r, a] = pixel(&canvas, w, 32, 32);
        assert_eq!(
            (r, g, b, a),
            (0x7d, 0xcf, 0xff, 0xff),
            "fill must stay cyan"
        );

        let [b, g, r, a] = pixel(&canvas, w, 1, 32);
        assert_eq!(
            (r, g, b, a),
            (0xbb, 0x9a, 0xf7, 0xff),
            "border must stay purple"
        );
    }
}
