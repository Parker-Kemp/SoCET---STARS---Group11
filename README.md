# INT8 Systolic Array Accelerator

STARS Mini Project, Fall 2026 (Group 11)

A 4x4 systolic array matrix multiplier on an FPGA, built as a small AI inference accelerator. A Python program on a PC streams 8-bit integer (INT8) matrices to the FPGA over UART, the array computes the products, and the results are checked against a Python reference model. We use the accelerator to run a small neural network that classifies handwritten digits, and benchmark it against a simpler sequential multiplier.

## Getting started

1. **Set up the toolchain** by following [docs/setup.md](docs/setup.md). It lists the exact versions we use and how to install them.
2. **Clone the repo into a folder path with no spaces** (for example `C:\Users\<name>\Downloads\SOCET-PROJECT\`). Verilator fails in paths that contain spaces.

   ```powershell
   git clone https://github.com/Parker-Kemp/SoCET---STARS---Group11.git stars-systolic-accelerator
   ```

3. **Open the repo folder in VS Code** with File > Open Folder, and install the recommended extensions when prompted.

## Toolchain at a glance

| Tool | Version | Used for |
| --- | --- | --- |
| Verilator | 5.036 (matches the asicfab server) | Simulation and linting, run through WSL |
| GTKWave | 3.3.124 on asicfab | Viewing waveforms |
| Yosys (YoWASP) | 0.70 | TerosHDL schematic viewer, later synthesis |
| Python | 3.14 | All scripts, including UART to the FPGA |
| VS Code + TerosHDL | Latest | Editing, diagrams, documentation |

Full install steps and troubleshooting are in [docs/setup.md](docs/setup.md).

## Repository structure

| Folder | Contents |
| --- | --- |
| `rtl/` | SystemVerilog hardware modules |
| `tb/` | SystemVerilog testbenches |
| `tb/vectors/` | Test vector files (hex) |
| `python/` | Python scripts |
| `fpga/` | Pin constraints and FPGA project files |
| `scripts/` | Build, simulation, and regression scripts |
| `docs/proposal/` | Project proposal |
| `docs/checkins/` | Milestone check-ins |
| `docs/report/` | Final report and presentation |
| `docs/figures/` | Diagrams for documentation |
| `results/plots/` | Benchmark and accuracy plots |
| `results/waveforms/` | Labeled waveform screenshots |
| `results/benchmarks/` | Raw benchmark data |

## Running a simulation

From VS Code's terminal, in the repo's top folder:

```powershell
wsl verilator --binary --timing -Wall --trace --top-module tb_pe tb/tb_pe.sv rtl/pe.sv
wsl ./obj_dir/Vtb_pe
wsl gtkwave tb_pe.vcd
```

Replace `tb_pe` and the file names with the testbench and modules you are testing.

## Daily Git workflow

```powershell
git pull                          # before you start: get everyone else's changes
git add <files>                   # stage the files you changed
git commit -m "Describe the change"
git push                          # upload your commits
```

- Always `git pull` before starting work.
- Commit small, working pieces with clear messages, and push regularly.
- Never commit generated files (`obj_dir/`, `.vcd` waveforms, `__pycache__/`). The `.gitignore` handles most of these.

## Adding a new module

1. Create the file in `rtl/` (or `tb/` for a testbench) from VS Code's Explorer, with a `.sv` extension. Name the file after the module it contains, for example `pe.sv` for `module pe`.
2. In the TerosHDL sidebar, click **+** next to **Files**, choose **Source**, and select the file.
3. Save the TerosHDL project (the save icon next to **Files**) so the project file in the repo stays up to date.
4. Commit the new file and the updated project file together.

## Team

| Name | Role |
| --- | --- |
| TODO | Compute core (PE, systolic array, skew logic, baseline) |
| TODO | Communication and control (UART, FSM, buffers, cycle counter) |
| TODO | Software and machine learning (Python driver, training, inference) |
| TODO | Verification and benchmarking (golden model, testbenches, benchmarks) |

## Timeline

| Deliverable | Due |
| --- | --- |
| Milestone Check-in 1 | Sat 10/31, 11:59pm |
| Milestone Check-in 2 | Sat 11/14, 11:59pm |
| Milestone Check-in 3 | Sun 11/29, 11:59pm |
| Presentation | Thu 12/10, 4:30pm |
| Final Report | Fri 12/18, 11:59pm |
