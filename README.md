# Edge-Detection Hardware in Verilog, Verified with cocotb and CI

![RTL verification](https://github.com/VictorMartinez89/edge-detection-verilog/actions/workflows/ci.yml/badge.svg)

Sobel and Canny edge-detection filters written in SystemVerilog, **bit-exact against Python golden models**
and verified automatically on every push with **GitHub Actions**.

They come from my M.Sc. thesis in Electronic Engineering (Universidad Nacional de Colombia, 2026), where the same
cores ran on a Lattice iCE40UP5K FPGA with a live camera and were taken to SkyWater **sky130** silicon layouts with
OpenLane.

## Design rules

- **100 % combinational datapaths with no multipliers or dividers.** Kernel coefficients `{-2,-1,0,1,2}` are built
  with `+`, `-` and `<<`; divisions are shifts. Gaussian kernels are binomial, so they sum to a power of two.
- **Bit-exact verification.** A design is correct only if it reproduces the golden model on every pixel.

## Modules (`rtl/`)

| Module | What it does |
|---|---|
| `sobel_compass_core` | 8 directional Sobel kernels (N, NE, E … NW): magnitude and direction of the strongest edge |
| `sobel_compass_control` | Streaming wrapper: sliding 3×3 window over a raster image |
| `gaussian_core` | 3×3, 5×5 and 7×7 binomial Gaussian smoothing |
| `isqrt` | Combinational integer square root |
| `canny_grad_threshold_core` | Gradient magnitude √(Gx²+Gy²) and threshold |
| `nms_core` | Non-maximum suppression (edge thinning) |
| `canny_full_core` / `canny_control` | Single-pass Canny (NMS + hysteresis) on a pixel stream |

## Verification

| Level | Tool | What it checks |
|---|---|---|
| Lint | Icarus Verilog (`-Wall`) | Every file compiles; catches implicit nets that synthesis tools accept silently |
| Testbench | SystemVerilog (`tb/tb_filters.sv`) | Self-checking tests of the combinational cores |
| Regression | **cocotb** + NumPy (`tests/`) | Streams images through the RTL and compares every output pixel with a golden model |
| CI | **GitHub Actions** | Runs all of the above on every push and pull request, and keeps the JUnit results |

The streaming tests feed images in raster order and check only the valid interior pixels, so the window logic,
line boundaries and latency are exercised, not just isolated pixels.

## Run it locally

Requires Icarus Verilog 12+, Python 3.10+ and `pip install cocotb==2.0.1 numpy`.

```bash
make all          # lint + testbench + cocotb regression
make test-canny   # a single cocotb test: sobel_compass, canny or nms
make clean
```

## Context

- Hardware results (FPGA and sky130 layouts) and the full thesis:
  [tty_project_filter](https://github.com/VictorMartinez89/tty_project_filter).
- Code comments are in Spanish, the language of the thesis.

## License

MIT
