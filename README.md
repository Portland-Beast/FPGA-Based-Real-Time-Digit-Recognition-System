# FPGA-Based Real-Time Digit Recognition System

> **UIUC ECE 385 — Digital Systems Laboratory, Fall 2025 Final Project**

![System Architecture](final_demo.png)

## Overview

A real-time handwritten digit recognition system (0–9) on FPGA. An OV7670 camera captures 100×80 RGB565 images, a LeNet-5 style CNN extracts features through two convolution-pooling stages, and a fully connected layer classifies the digit. The result is displayed on an HDMI monitor in real time.

## System Architecture

### Processing Pipeline

```
OV7670 Camera (100×80 RGB565)
    │
    ▼
C1: 3×3 Gaussian Convolution ──→ 98×78×3 (RGB565)
    │
    ▼
P1: 2×2 Max Pooling ───────────→ 49×39×3 (RGB565)
    │
    ▼
C2: 3×3 Gaussian Convolution ──→ 47×37×3 (RGB565)
    │
    ▼
P2: 2×2 Max Pooling ───────────→ 23×18×3 (RGB565)
    │
    ▼
Grayscale + Flatten ────────────→ 748 features (8-bit)
    │
    ▼
FC1 → FC2 → Output Layer ──────→ 10 classes (digit 0–9)
    │
    ▼
HDMI Display (640×480)
```

### Camera Interface (OV7670)

The OV7670 module outputs RGB565 pixel data over an 8-bit parallel bus, requiring two PCLK cycles per pixel. The interface consists of three modules:

- **`ov7670_fsm`** — Writes 73 configuration registers via I2C (SCCB protocol) at startup, including RGB565 output format (`0x40=0xD0`), scaling/downsampling (`0x0C=0x04`, `0x3E=0x1A`), and HSTART/HSTOP/VSTART/VSTOP window settings for 100×80 resolution.
- **`ov7670_capture`** — State machine that synchronizes to VSYNC/HREF edges (sampled into the system clock domain via double-FF synchronizers), captures two bytes per pixel on PCLK rising edges, and writes 16-bit RGB565 data to `pixel_memory` BRAM. Tracks 80 lines × 100 pixels per frame.
- **`i2c_master`** — Standard I2C master at 100 kHz (derived from 100 MHz system clock), supporting multi-byte write transactions to the OV7670 address `0x42`.

### CNN Convolution Layers (C1, C2)

Each convolution layer processes R, G, B channels independently through three parallel `cnn_gus` instances:

- **Sliding window**: A `cnn_read` controller generates 3×3 window addresses by maintaining row (`cnt_h`), column (`cnt_l`), and intra-window (`cnt`) counters. The address formula `cnt_l + cnt_h × WIDTH + cnt + cnt_n × (WIDTH - 3)` maps the 2D sliding window to linear BRAM addresses.
- **MAC unit** (`cnn_gus`): 2-stage pipelined multiply-accumulate. Stage 1 registers the product `a × b`; stage 2 accumulates over 9 taps. The Gaussian kernel weights are `[1,2,1; 2,4,2; 1,2,1]`, normalized by right-shifting the result by 4 bits (`>> 4`).
- **RGB recombination**: After per-channel processing, outputs are recombined to RGB565 format `{R[7:3], G[7:2], B[7:3]}`.

C1 processes 100×80 → 98×78 (7,644 pixels); C2 processes 49×39 → 47×37 (1,739 pixels).

### Pooling Layers (P1, P2)

Each pooling layer performs 2×2 max pooling per RGB channel via `pool_core` instances:

- **Address generation**: `pool_read_p1`/`pool_read_p2` generate 2×2 window addresses with stride-2 stepping (`cnt_l += 2`, `cnt_h += 2`).
- **Max selection**: Each `pool_core` compares 4 input values and outputs the maximum, reducing spatial dimensions by 2× in each direction.
- **Triggering**: Each layer starts when the previous layer's `ram_wen` goes high, creating a self-propagating pipeline.

P1: 98×78 → 49×39; P2: 47×37 → 23×18.

### Fully Connected Layers

After P2, the feature maps are flattened and processed through three FC stages:

- **`pre_layer`** — Reads P2 output (RGB565), converts to 8-bit grayscale, and flattens the 2D feature maps into a 748-element 1D vector stored in `pre_1024` BRAM.
- **`conv1_layer1`** / **`conv2_layer2`** — Sequential MAC operations: for each output neuron, accumulate `weight[i] × input[i]` over all input features, add bias, and apply fixed-point scaling (right-shift normalization). Weights are loaded from `weights/` via `$readmemh`.
- **`full_layer`** — Final classification layer producing 10 output scores. The `argmax` determines the recognized digit.
- **`output_layer`** — Maps the recognized digit (0–9) to a 28×28 bitmap stored in BRAM for display.

### Display Controller

- **VGA timing** at 640×480@60Hz with 25 MHz pixel clock.
- **Address generation**: Maps VGA pixel coordinates to BRAM read addresses based on the active layer's resolution (`disp_width × disp_height`).
- **Layer selection mux**: A `layer_select` signal routes one of five data sources (C1/P1/C2/P2/Final) to the VGA RGB output, enabling visual debugging of intermediate layers.
- **HDMI output**: The `hdmi_tx_0` IP core serializes VGA RGB + sync signals into TMDS differential pairs using the 125 MHz (5× pixel clock) serializer.

### Clock Domains & Synchronization

| Clock | Frequency | Domain |
|-------|-----------|--------|
| `i_top_clk` | 100 MHz | Camera capture, I2C, reset logic |
| `CLK_25MHZ` | 25 MHz | CNN pipeline, VGA, display (main processing) |
| `CLK_125MHZ` | 125 MHz | HDMI TMDS serializer |
| `CLK_24MHZ` | ~24 MHz | OV7670 XCLK |
| `PCLK` | async | Camera pixel clock |

All clocks are generated by `clk_wiz_0` from the 100 MHz input. Camera signals (`VSYNC`, `HREF`, `PCLK`, `DATA`) are synchronized into the system clock domain via double-FF synchronizers. The `frame_finished` signal crossing from 100 MHz to 25 MHz uses a rising-edge detector to trigger the CNN pipeline once per captured frame.

## Project Structure

```
├── src/                              # SystemVerilog source files
│   ├── Final_project_top.sv          # Top-level module
│   ├── camera/                       # OV7670 camera interface
│   │   ├── ov7670_capture.sv         #   Pixel capture FSM
│   │   ├── ov7670_configuration.sv   #   I2C register configuration
│   │   ├── ov7670_fsm.sv            #   Camera setup state machine
│   │   └── i2c_master.sv            #   I2C master controller
│   ├── cnn/                          # Convolution layers
│   │   ├── cnn3.sv                   #   3×3 convolution unit (RGB)
│   │   ├── cnn_gus.sv               #   Gaussian convolution core
│   │   ├── cnn_read.sv              #   C1 read controller
│   │   ├── cnn_read_c2.sv           #   C2 read controller
│   │   ├── conv1.sv / conv1_layer1.sv   # Conv/FC layer 1
│   │   └── conv2.sv / conv2_layer2.sv   # Conv/FC layer 2
│   ├── pooling/                      # Pooling layers
│   │   ├── pool3.sv                  #   2×2 max pooling (RGB)
│   │   ├── pool_core.sv / pool_core0.sv  # Pooling computation cores
│   │   ├── pool1_layer.sv           #   Pooling layer 1 wrapper
│   │   ├── pool_read_p1.sv          #   P1 read controller
│   │   └── pool_read_p2.sv          #   P2 read controller
│   ├── fc/                           # Fully connected & output
│   │   ├── pre_layer.sv             #   Flatten 2D → 1D (748 features)
│   │   ├── full_layer.sv            #   FC → 10 classes
│   │   └── output_layer.sv          #   Digit display bitmap lookup
│   ├── display/                      # VGA/HDMI display
│   │   ├── display_controller.sv    #   VGA timing & pixel output
│   │   ├── vga_sync_gen.sv          #   Sync signal generator
│   │   └── rgb2gray.sv              #   RGB to grayscale conversion
│   └── utils/                        # Utilities
│       ├── sync_debounce.sv          #   Button debounce & sync
│       └── read_ramp2.sv            #   Memory read helper
├── constraints/
│   └── Urbana.xdc                    # FPGA pin assignments (Urbana board)
├── ip/                               # Xilinx IP cores (.xci)
│   ├── clk_wiz_0/                    #   PLL: 25/125/24 MHz from 100 MHz
│   ├── pixel_memory/                 #   16-bit × 8100 dual-port BRAM
│   ├── img_cache/                    #   C1 layer result cache
│   ├── mid_cache/                    #   P1/C2 intermediate cache
│   ├── end_cache/                    #   P2 layer result cache
│   ├── pre_1024/                     #   Flatten layer cache
│   ├── full_cache/ full_cache_256/   #   FC layer caches
│   ├── full_cache_512/ full_cache_1024/
│   ├── conv2_cache/                  #   Conv2 layer cache
│   └── hdmi_tx_0/                    #   VGA → HDMI (TMDS encoder)
├── weights/                          # Pre-trained CNN weights (hex)
│   ├── conv1_weight_{1,2,3}.txt      #   Conv1 kernels (5×5 × 3ch)
│   ├── conv2_weight_{11..33}.txt     #   Conv2 kernels (5×5 × 9)
│   ├── conv1_bias.txt / conv2_bias.txt
│   ├── fc_weight.txt / fc_bias.txt   #   FC layer (48×10)
│   └── 0_20.txt ~ 0_29.txt          #   Digit display bitmaps (28×28)
├── verification/
│   └── cnn_model.py                  # Python CNN for HW/SW validation
└── vivado/
    └── newone.xpr                    # Vivado project file
```

## Weight Files

Pre-trained on MNIST via PyTorch, sourced from [CNN-Implementation-in-Verilog](https://github.com/boaaaang/CNN-Implementation-in-Verilog).

| Files | Description |
|-------|-------------|
| `conv1_weight_{1,2,3}.txt`, `conv1_bias.txt` | Conv1: 5×5 kernels, 3 channels |
| `conv2_weight_{11..33}.txt`, `conv2_bias.txt` | Conv2: 5×5 kernels, 3×3 channels |
| `fc_weight.txt`, `fc_bias.txt` | Fully connected layer (48×10) |
| `0_20.txt` ~ `0_29.txt` | 28×28 digit bitmaps for display |

Format: hex text, 8-bit signed two's complement, loaded via `$readmemh()`.

## Software Verification

`verification/cnn_model.py` implements the identical CNN pipeline (Conv1 → Pool1 → Conv2 → Pool2 → FC) in Python using the same weight files. This enables layer-by-layer comparison between FPGA hardware output and software golden reference.

```bash
pip install numpy matplotlib Pillow
python verification/cnn_model.py
```

## Top-Level I/O

| Signal | Dir | Description |
|--------|-----|-------------|
| `i_top_clk` | in | 100 MHz system clock |
| `i_top_rst` | in | Active-high reset |
| `i_top_cam_start` | in | Start capture & recognition |
| `i_top_pclk`, `i_top_pix_vsync`, `i_top_pix_href` | in | Camera timing signals |
| `i_top_pix_byte[7:0]` | in | Camera pixel data |
| `o_top_siod` / `o_top_sioc` | inout | I2C data / clock |
| `o_top_24clk`, `o_top_reset`, `o_top_pwdn` | out | Camera clock, reset, power |
| `o_top_cam_done` | out | Configuration complete flag |
| `hdmi_tmds_clk_p/n`, `hdmi_tmds_data_p/n[2:0]` | out | HDMI differential output |

## Layer Debug

Modify `layer_select` in `src/Final_project_top.sv` to inspect intermediate results on HDMI:

```systemverilog
assign layer_select = 3'b101;  // 001:C1  010:P1  011:C2  100:P2  101:Final
```
