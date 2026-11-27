# Vitis-Develop-Environment

Build, boot, flash and debug Vitis 2022.2 bare-metal / FreeRTOS projects from the terminal instead of the
Vitis IDE. Everything is driven by two config files; the Vitis workspace is generated and disposable, so a
broken project is fixed by rebuilding it, never by clicking around.

Under the hood these scripts call the same tools the IDE uses: `xsct` (Tcl), `bootgen`, `program_flash`
and `hw_server`.

## Requirements

**An x86_64 PC with Vitis 2022.2 installed, on Linux or Windows.** Vitis does not run on ARM hosts
(e.g. Raspberry Pi); there only `uart.sh` works.

Every script exists twice: `scripts/NAME.sh` for Linux, `scripts\NAME.bat` for Windows. Both run the
same Tcl code in `scripts/tcl/`, so behaviour is identical.

**Linux**
- `unzip`, and one of `picocom` / `minicom` / `screen` (for `uart.sh`).
- Serial port access: `sudo usermod -aG dialout $USER`, then log out and back in.
- JTAG cable drivers (`<Vitis>/data/xicom/cable_drivers/lin64/install_script/install_drivers`, as root).

**Windows**
- Windows 10 or newer (its built-in `tar` unpacks the XSA). Nothing else to install.
- Run the `.bat` scripts from `cmd` or PowerShell (in PowerShell: `.\scripts\build_app.bat`).
- **No spaces in the project path** (e.g. use `C:\work\myproj`, not `C:\Users\Lan Tran\...`). Vitis
  breaks on them; the scripts refuse to run there. (Same rule on Linux.)
- JTAG cable drivers are installed by the Vitis installer (option "Install Cable Drivers").

## Quick start

On Windows use `scripts\NAME.bat` instead of `./scripts/NAME.sh` and set `VITIS_PATH_WINDOWS`.

```bash
# 1. once: tell it where Vitis is
nano config/vitis.env                 # VITIS_PATH=/tools/Xilinx/Vitis/2022.2  (Windows: VITIS_PATH_WINDOWS)

# 2. drop the XSA exported from Vivado (with bitstream) into hw/
cp ~/vivado_proj/design_1_wrapper.xsa hw/
./scripts/xsa_info.sh                 # lists processor names to put in the config

# 3. describe platform + apps
nano config/project.cfg

# 4. build and run
./scripts/build_platform.sh           # platform, BSPs, FSBL (and PMUFW on ZynqMP)
./scripts/build_app.sh                # apps -> build/out/<app>.elf
./scripts/uart.sh                     # in a second terminal: see the board's output
./scripts/debug.sh                    # load over JTAG, stop at main(), debug shell
./scripts/make_boot.sh                # build/boot/BOOT.BIN
./scripts/flash.sh                    # program QSPI over JTAG, or copy to SD card
```

## Folder layout

| Path | What | Who edits |
|---|---|---|
| `config/vitis.env` | Vitis install path (`VITIS_PATH` Linux, `VITIS_PATH_WINDOWS` Windows) | you, once |
| `config/project.cfg` | platform, domains, apps, boot, flash, JTAG, UART settings. `KEY_windows` overrides `KEY` on Windows (e.g. `port_windows = COM3`) | you |
| `hw/` | the `.xsa` from Vivado | you |
| `src/<app>/` | application sources + `lscript.ld` (seeded from the template on first build) | you |
| `scripts/*.sh` | entry points | — |
| `scripts/tcl/*.tcl` | the actual logic, run by `xsct` | — |
| `build/` | **generated**: Vitis workspace, extracted XSA, ELFs, BOOT.BIN. Safe to delete. | nobody |

## Scripts

Names below without extension: `.sh` on Linux, `.bat` on Windows. Arguments are the same.

| Script | Does |
|---|---|
| `xsa_info.sh` | List processors and UART/debug IPs in the XSA |
| `build_platform.sh` | Wipe `build/`, create the platform from the XSA, one domain (BSP) per `[domain]`, generate |
| `build_app.sh [APP] [--clean]` | Create the app if needed, copy `src/APP/` into it (files you deleted are deleted there too), build, copy ELF to `build/out/`. `--clean` recreates the app project (use after changing `template`/`defines`/`libs`) |
| `make_boot.sh` | Write `build/boot/boot.bif` (FSBL, PMUFW, bitstream, apps) and run `bootgen` |
| `flash.sh` | `[flash] method = jtag`: `program_flash` (board in JTAG boot mode). `method = sd`: copy BOOT.BIN to `sd_path` |
| `debug.sh [APP]` | Reset board, program PL, init PS (ps7_init / psu_init), download ELF, stop at `main()`, open the xsct debug shell |
| `debug.sh [APP] --run` | Same, but just run the app and exit |
| `xsct_shell` | Interactive xsct with the Vitis environment and debug helpers loaded |
| `uart [PORT] [BAUD]` | Serial terminal (defaults from `[uart]`). Linux: picocom/minicom/screen. Windows: built-in terminal, quit with `~.` + Enter |
| `jtag_uart [APP]` | Terminal on the JTAG UART of the app's core (no serial cable needed). Quit with `~.` + Enter |
| `clean.sh` | Delete `build/` |

When the hardware changes: export a new XSA into `hw/`, then `build_platform.sh` and `build_app.sh`.
Your `src/` is never touched by either.

## Debugging

`debug.sh` leaves you in an xsct shell stopped at `main()`. Short aliases (type `dbg_help`):

```
b main | b main.c:42 | b 0x100000    breakpoint            bl / bd ID / bd all   list / delete
c                                   continue              halt                  stop the core
s / n / fin                         step into/over/out    bt                    backtrace
p count / p buf[3] / p *ptr         print variable        l                     local variables
regs                                registers             x 0x41200000 4        read 4 words
mwr 0x41200000 0x1                  write memory          targets               list JTAG targets
reload                              re-download ELF after build_app.sh (no board reset)
restart ?app?                       reset board, load, stop at main          exit   quit
```

All normal xsct commands work too (`bpadd`, `con`, `stp`, `nxt`, `print`, `locals`, `mrd`, `rrd`, ...).
Typical loop: edit code → `./scripts/build_app.sh` in another terminal → `reload` in the debug shell.

**JTAG UART:** for Arm cores set `bsp.stdout = ps7_coresight_comp_0` (Zynq) or `psu_coresight_0` (ZynqMP)
in the domain, rebuild the platform, then use `jtag_uart.sh`. For MicroBlaze, use an MDM with JTAG UART.

**Need the GUI for something?** The generated workspace is a normal one: `vitis -workspace build/workspace`.

## Supported devices

| | Platform / app build | JTAG debug/run | BOOT.BIN / flash |
|---|---|---|---|
| Zynq-7000 (`ps7_cortexa9_*`) | yes | yes | yes |
| Zynq UltraScale+ (`psu_cortexa53_*`, `psu_cortexr5_*`) | yes | yes | yes |
| MicroBlaze | yes | yes | no (use Vivado `updatemem` / bootloader) |
| Versal | yes | no | no |

Notes:
- Zynq-7000 AMP: the FSBL starts only core 0; your core-0 app must wake core 1 (write its start address
  to `0xFFFFFFF0` + `sev`).
- ZynqMP boot image assumes the FSBL runs on A53-0 (the Vitis default).

The built-in terminal (Windows `uart`, and `jtag_uart` on both OSes) is line-based: text is sent when you
press Enter (with a CR), board output appears as it arrives.

## Verification status

Written against the Vitis 2022.2 XSCT command set (UG1400) and the command sequences the IDE generates.
It was dry-run end-to-end against a mock `xsct`/`bootgen`/`program_flash` (Zynq single core, ZynqMP A53+R5
AMP, SD + JTAG flash, debug, JTAG UART, serial terminal over a pseudo-tty, Windows config overrides), but
**not yet on real Vitis hardware, and the `.bat` files have not been executed on Windows yet**.
The first real run should check:

- `program_flash` 2022.2 option spelling (`-cable type xilinx_tcf url ...`). The full command is printed
  before it runs; add or adjust options via `[flash] extra_args`.
- `platform create` without `-proc` still generates FSBL/PMUFW (it should; `make_boot.sh` reports clearly if not).
- `xsct -interactive <script>` keeps the shell open after `debug.sh`. If not, run `xsct` and
  `source scripts/tcl/debug.tcl` (with `VDE_ROOT`/`VDE_CONFIG` exported).
- Windows: typed input reaches the built-in terminal (xsct reading the console in script mode).
