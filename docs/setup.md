# Toolchain Setup

This document lists the exact tool versions our team uses and how to install them, so everyone's environment matches. Our reference environment is the **asicfab** server: local setups should match its versions.

## Tool versions

| Tool | Version | Where it runs | Notes |
| --- | --- | --- | --- |
| Verilator | 5.036 (2025-04-27) | WSL (Ubuntu) | Built from source at tag `v5.036`. Matches asicfab. |
| GTKWave | 3.3.124 on asicfab | WSL (Ubuntu) | Waveform viewer only; a slightly different local version is fine. |
| Python | 3.14 | Windows | Runs all scripts, including UART to the FPGA. |
| Yosys (YoWASP) | 0.70 | Windows | `pip install yowasp-yosys`. Used by the TerosHDL schematic viewer and later for synthesis. |
| TerosHDL | Latest | VS Code | Diagrams, testbench templates, documentation. Its linter stays off. |
| Python packages | See `requirements.txt` | Windows | Install with `pip install -r requirements.txt`. |
| Git | Latest Git for Windows | Windows | |
| VS Code | Latest | Windows | Extensions listed below. |
| WSL | WSL 2, Ubuntu | Windows | Needed only to run Verilator and GTKWave. |
| FPGA tools | TODO: board name and vendor software version | Windows | |

Icarus Verilog and Yosys are **not** installed on asicfab, so we use Verilator for all simulation.

## Important: no spaces in your folder path

Verilator's build step fails if the project path contains spaces, with the error `GNU Make cannot build in directories containing spaces`. Clone the repo somewhere like `C:\Users\<name>\Downloads\SOCET-PROJECT\`, never inside a folder such as `SOCET - PROJECT`.

## Setup steps (Windows)

### 1. Install Git

In PowerShell:

```powershell
winget install --id Git.Git -e
```

Close and reopen PowerShell, then set your name and email (use your GitHub email):

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### 2. Clone the repository

From a folder with no spaces in its path:

```powershell
git clone https://github.com/Parker-Kemp/SoCET---STARS---Group11.git stars-systolic-accelerator
```

### 3. Install WSL and Ubuntu

In PowerShell **as administrator**:

```powershell
wsl --install
```

Restart your computer. If `wsl -l -v` does not list Ubuntu afterward, run `wsl --install -d Ubuntu`. Create a Linux username and password when prompted (the password is invisible as you type).

### 4. Build Verilator 5.036

Open **Ubuntu** from the Start menu and run:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt-get install -y git help2man perl python3 make autoconf g++ flex bison ccache libfl2 libfl-dev zlib1g zlib1g-dev gtkwave
cd ~
git clone https://github.com/verilator/verilator
cd verilator
git checkout v5.036
autoconf
./configure
make -j$(nproc)
sudo make install
verilator --version
```

The last command must print `Verilator 5.036`. The `make` step takes several minutes. The `apt-get` line also installs GTKWave.

### 5. Set up VS Code

1. Open the repo folder with **File > Open Folder**.
2. Install these extensions (VS Code will also prompt you, from `.vscode/extensions.json`):
   - **Verilog-HDL/SystemVerilog** (mshr-h): syntax highlighting and Verilator linting
   - **Python** (Microsoft)
3. Linting settings are shared in `.vscode/settings.json`:

```json
{
  "verilog.linting.linter": "verilator",
  "verilog.linting.verilator.useWSL": true,
  "verilog.linting.verilator.arguments": "-Wall"
}
```

### 6. Set up Python

1. Install the Python version listed in the table from python.org, and check **Add Python to PATH** during setup.
2. In VS Code, press **Ctrl+Shift+P**, choose **Python: Create Environment > Venv**, and select that Python.
3. In VS Code's terminal:

```powershell
pip install -r requirements.txt
```

### 7. Add Python to your PATH

If `python` or `yowasp-yosys` gives a "not found" error, Windows doesn't know where Python lives. Find your Python's location:

```powershell
py -c "import sys; print(sys.executable)"
```

Then add its folder and its `Scripts` folder to your PATH, replacing the path with your own:

```powershell
$py = "C:\Users\<name>\AppData\Local\Python\pythoncore-3.14-64"
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$py;$py\Scripts", "User")
```

Close and reopen VS Code completely afterward.

### 8. Install Yosys and TerosHDL's Python package

```powershell
python -m pip install yowasp-yosys teroshdl
```

### 9. Set up TerosHDL

1. Install the **TerosHDL** extension in VS Code.
2. Open TerosHDL's settings (the gear icon next to the project, or **Open Global Settings Menu**):
   - **General:** set **Python3 binary path** to your full `python.exe` path.
   - **Linter settings:** set every linter to disabled. Verilator linting comes from the Verilog-HDL/SystemVerilog extension instead.
   - **Schematic viewer:** backend **YoWASP**. Leave the "extra options" box empty.
3. Click **Verify Setup**. Expected result: everything passes except **GHDL** (a VHDL simulator we don't use) and **make** (not needed on Windows). `cocotb` (optional) may also show as missing.
4. Load the team's TerosHDL project from the repo if one is saved there, or create a project and add the files in `rtl/` and `tb/` as **Source**.

### 10. Verify everything works

In VS Code's terminal, from the repo folder:

```powershell
wsl verilator --version                 # should print 5.036
python --version                        # should print 3.14
python -m serial.tools.list_ports       # lists the FPGA's COM port when plugged in
```

## Running simulations

Verilator runs through WSL, called from VS Code's normal PowerShell terminal by prefixing commands with `wsl`:

```powershell
wsl verilator --binary --timing -Wall --trace --top-module tb_pe tb/tb_pe.sv rtl/pe.sv
wsl ./obj_dir/Vtb_pe
wsl gtkwave tb_pe.vcd
```

- `--binary --timing` lets Verilator run normal SystemVerilog testbenches with `#` delays and `@(posedge clk)`.
- `--trace` enables waveform output; the testbench must call `$dumpfile` and `$dumpvars`.
- On Windows 11, `wsl gtkwave` opens GTKWave as a normal window.

## Where things run

- **Simulation** (Verilator, GTKWave): WSL, called from the VS Code terminal.
- **Python scripts and FPGA communication**: Windows. WSL cannot easily access USB serial ports, and the FPGA appears as a COM port on Windows.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `git` is not recognized | Git is not installed, or PowerShell was opened before installing. Install Git, then open a new terminal. |
| `GNU Make cannot build in directories containing spaces` | Move the repo to a path with no spaces. |
| Ubuntu fails to start with a virtualization error (often `0x80370102`) | Enable virtualization in your computer's BIOS settings. |
| `python` or `yowasp-yosys` not found | Add Python and its Scripts folder to your PATH (step 7), then restart VS Code. |
| TerosHDL Verify Setup shows Python path as empty | Re-enter the path in TerosHDL's General settings, and in the global settings menu if needed. |
| GitHub rejects your password when pushing | Sign in through the browser prompt, or use a personal access token. |
| `Cannot find file containing module` | Check the file path, and that you are running the command from the repo's top folder. |

## Checking versions on the server

To confirm the reference versions, SSH into asicfab and run:

```bash
verilator --version
gtkwave --version
python3 --version
```

If the server's tools are ever updated, update this document and have everyone match the new versions.
