//! Rasteriser benchmark. Run with `cargo bench`.

use divan::black_box;
use split_tree_overlay::paint::paint;

// Tokyo Night straight RGBA. Values only affect coverage maths, not the amount of work.
const FILL: [u8; 4] = [0x7d, 0xcf, 0xff, 0x66];
const BORDER: [u8; 4] = [0xbb, 0x9a, 0xf7, 0xcc];
const BORDER_WIDTH: i32 = 3;
const ROUNDING: i32 = 8;

fn main() {
    // `cargo bench` uses the optimised `bench` profile.
    // If assertions are on we were built unoptimised which is ~20x slower.
    if cfg!(debug_assertions) {
        eprintln!("warning: benchmark built unoptimised.");
        eprintln!("         run `cargo bench`, not `cargo bench --profile dev`.\n");
    }

    divan::main();
}

#[divan::bench(
    args = [
        ("960x540", 960u32, 540u32),
        ("1080p", 1920u32, 1080u32),
        ("4K", 3840u32, 2160u32),
    ],
    sample_count = 20,
)]
fn paint_rect(b: divan::Bencher, (_name, width, height): (&'static str, u32, u32)) {
    let mut canvas = vec![0u8; width as usize * height as usize * 4];
    b.bench_local(|| {
        paint(
            black_box(canvas.as_mut_slice()),
            width,
            height,
            black_box(FILL),
            black_box(BORDER),
            black_box(BORDER_WIDTH),
            black_box(ROUNDING),
        );
    });
}
