# AMD GPU Monitor

A real-time AMD GPU monitoring plugin for Noctalia Shell with comprehensive metrics and customizable graphs.

## Features

- **Panel Widget**: Full GPU monitoring interface with real-time graphs
- **Bar Widget**: Compact GPU status display in the bar
- **Real-time Graphs**: Visual graphs for all metrics with customizable colors
- **Multi-sensor Temperature**: Monitor Junction, Edge, and Memory temperatures
- **Multiple Clock Speeds**: Track SCLK, MCLK, FCLK, SOCCLK, and DCEFCLK
- **Priority Thresholds**: Automatic color changes at 75% (warning) and 90% (critical) for GPU usage
- **VRAM Monitoring**: Track VRAM usage and activity
- **Customizable Metrics**: Show/hide any metric via settings
- **Theme Integration**: Uses Noctalia Shell theme colors for graphs and icons
- **Settings**: Configure visible metrics, colors, and display preferences

## Usage

Add the bar widget to your bar, or open the panel for full GPU monitoring. The panel displays all available metrics with real-time graphs.

### Panel

The panel provides a comprehensive view of all GPU metrics with mini-graphs for each metric. Metrics include:

- **GPU Usage**: Real-time GPU utilization with threshold-based coloring (green → yellow at 75% → red at 90%)
- **Temperature**: Multi-line graph supporting Junction, Edge, and Memory temperature sensors
- **VRAM**: Memory usage and optional activity monitoring
- **Fan Speed**: Cooling fan speed in percentage
- **Power**: Power consumption in watts
- **Clock Speeds**: Multi-line graph for SCLK, MCLK, FCLK, SOCCLK, and DCEFCLK

### Bar Widget

The bar widget shows a compact overview of GPU status directly in the bar.

### Temperature Sensors

Choose which temperature sensor to display as primary:
- **Junction**: GPU junction temperature (default)
- **Edge**: GPU edge temperature
- **Memory**: GPU memory temperature

Multiple sensors can be shown simultaneously on the temperature graph with different colors.

### Clock Speeds

Track up to 5 different clock speeds simultaneously:
- **SCLK**: Graphics clock (default)
- **MCLK**: Memory clock
- **FCLK**: Fabric clock
- **SOCCLK**: SoC clock
- **DCEFCLK**: DCEF clock

All visible clocks are displayed on a single multi-line graph with theme-based colors.

## Configuration

### Display Settings

- **Compact Mode**: Toggle between compact and detailed display
- **Icon Color**: Customize the icon color using theme colors
- **Text Color**: Customize text color (when compact mode is off)
- **Monospace Font**: Use fixed-width font for aligned values
- **Pad Values**: Enable padding for stable bar width (monospace only)

### Visible Metrics

Choose which metrics to display:
- GPU Usage
- Junction Temperature
- Edge Temperature
- Memory Temperature
- VRAM Usage
- VRAM Activity
- Fan Speed
- Power
- SCLK, MCLK, FCLK, SOCCLK, DCEFCLK

### Data Source

- **GPU Device Index**: Select which GPU to monitor (rocm-smi device index, 0 for first discrete GPU)

## Requirements

- **rocm-smi**: ROCm System Management Interface must be installed and available
- **AMD GPU**: Requires a discrete AMD GPU

## Troubleshooting

If the panel shows "GPU data unavailable":
1. Ensure `rocm-smi` is installed: `sudo pacman -S rocm-smi-lib` (Arch) or equivalent for your distro
2. Verify the discrete GPU is detected: `rocm-smi`
3. Check that you have proper permissions to access GPU data
4. Verify the correct device index in settings if you have multiple GPUs