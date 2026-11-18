# STM32H723

Bare-metal-ready VS Code + CMake development project for the Fanke FK723M1-ZGT6 / STM32H723ZGT6 board.

## Hardware

- MCU: STM32H723ZGT6
- Board: FK723M1-ZGT6
- Flash: 1 MB
- On-board user LED: PG7
- USB: Full-speed USB DFU bootloader (`0483:df11`)

## Prerequisites

- ARM GNU Toolchain (`arm-none-eabi-gcc`)
- CMake 3.22+
- Ninja
- dfu-util
- VS Code C/C++ and CMake Tools extensions

### Linux

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install gcc-arm-none-eabi binutils-arm-none-eabi cmake ninja-build dfu-util git
```

Fedora:

```bash
sudo dnf install arm-none-eabi-gcc arm-none-eabi-binutils arm-none-eabi-newlib cmake ninja-build dfu-util git
```

Arch Linux:

```bash
sudo pacman -S arm-none-eabi-gcc arm-none-eabi-binutils arm-none-eabi-newlib cmake ninja dfu-util git
```

To allow `dfu-util` to access the STM32 DFU device without `sudo`, create an
udev rule:

```bash
sudo bash -c 'cat > /etc/udev/rules.d/99-stm32-dfu.rules <<"EOF"
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", TAG+="uaccess", MODE="0660"
EOF'
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Then unplug and reconnect the board.

## Get the STM32 HAL

Clone the project, then fetch the required HAL and CMSIS sources. On Linux or macOS:

```bash
mkdir -p lib
git clone --depth 1 https://github.com/STMicroelectronics/STM32CubeH7.git lib/STM32CubeH7
cd lib/STM32CubeH7
git sparse-checkout set --skip-checks Drivers/CMSIS/Device/ST/STM32H7xx Drivers/STM32H7xx_HAL_Driver
git submodule update --init --depth 1 Drivers/CMSIS/Device/ST/STM32H7xx Drivers/STM32H7xx_HAL_Driver
cd ../..
```

PowerShell:

```powershell
mkdir lib
git clone --depth 1 https://github.com/STMicroelectronics/STM32CubeH7.git lib/STM32CubeH7
Set-Location lib/STM32CubeH7
git sparse-checkout set --skip-checks Drivers/CMSIS/Device/ST/STM32H7xx Drivers/STM32H7xx_HAL_Driver
git submodule update --init --depth 1 Drivers/CMSIS/Device/ST/STM32H7xx Drivers/STM32H7xx_HAL_Driver
Set-Location ../..
```

## Build

Linux, macOS, or PowerShell:

```bash
cmake --preset Debug
cmake --build --preset Debug
```

Output: `build/Debug/stm32h723-blinky.elf`, `.bin`, and `.hex`.

## Flash over USB DFU

1. Hold BOOT0/B0.
2. Tap RESET/NRST while holding BOOT0.
3. Keep holding BOOT0 for about two seconds, then release it.
4. Confirm that the STM32 DFU device is present:

```bash
lsusb
# The device should appear as: 0483:df11

dfu-util -l
```

5. Flash with CMake:

```bash
cmake --build --preset Debug --target flash
```

You can also invoke dfu-util directly:

```bash
dfu-util -d 0483:df11 -a 0 -s 0x08000000:leave -D build/Debug/stm32h723-blinky.bin
```

The board should leave DFU mode and run the PG7 blinky firmware.

## Linux permissions

If the device is visible in `lsusb` but `dfu-util` reports a permission error, use the udev rule in the Linux prerequisites above. Confirm the rule is loaded with:

```bash
udevadm test /sys/class/usb_device/* 2>/dev/null | grep -i uaccess
```

For a quick test, `sudo dfu-util -l` can confirm whether the board is visible. Reconnect the board after changing udev rules.

## Windows DFU driver

If dfu-util reports `LIBUSB_ERROR_NOT_SUPPORTED`, use Zadig once to bind the STM32 DFU interface to the WinUSB driver.

## Debugging

An ST-Link probe can be used with SWD (PA13/SWDIO and PA14/SWCLK). Debug configuration is in `.vscode/launch.json`.
