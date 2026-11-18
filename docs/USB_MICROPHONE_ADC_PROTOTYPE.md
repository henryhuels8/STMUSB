# STM32H723: One USB Microphone to ADC/DAC Prototype

## 1. Purpose

This document defines the first firmware milestone for the STM32H723/H723 generic development board:

```text
USB microphone
      |
      | digital PCM isochronous packets
      v
STM32 USB Host / UAC
      |
      | 48 kHz or resampled mono PCM ring buffer
      v
Audio service / DSP block
      |
      +---------------------->
      |                       DAC or I2S codec
      v                       |
DMA block buffer             analog reconstruction
      |                       |
      v                       v
MCU ADC or oscilloscope <---- loopback/analog output
      |
      v
Metering or software verification
```

Success criteria:

- The board enumerates exactly one supported USB microphone.
- PCM audio is received without steady-state underruns or overruns.
- A mono test signal is visible on the DAC output and/or ADC loopback.
- The firmware remains running after USB unplug/reconnect.
- Audio callbacks contain no USB stack calls, blocking calls, dynamic allocation, logging, or display updates.

This is deliberately a prototype, not a complete mixer:

- Only one USB microphone is required.
- A guitar/analog input is not part of this milestone.
- USB device recording is not part of this milestone.
- USB MIDI is not part of this milestone.
- Custom effects are not part of this milestone.

## 2. Important interpretation

A USB microphone is digital. Its PCM samples do not pass through the STM32 ADC.

There are two different paths:

1. **USB microphone to analog output:**

   ```text
   USB microphone -> USB Host/UAC -> PCM -> DAC/I2S -> analog output
   ```

2. **Analog guitar input:**

   ```text
   Guitar -> analog amplifier/input protection -> MCU ADC -> PCM
   ```

The complete prototype can also test an analog loopback:

```text
USB PCM -> MCU DAC -> cable -> MCU ADC -> meter
```

This verifies USB data, DAC output, ADC input, clocks, DMA, and software timing. It does not make the USB microphone signal physically pass through an ADC.

## 3. Current project state

The existing project is a bare-metal blinky project at:

- `src/main.c`
- `src/startup_stm32h723xx.s`
- `src/system_stm32h7xx.c`
- `STM32H723xx_FLASH.ld`
- `CMakeLists.txt`

It already provides:

- An ARM GNU toolchain setup.
- STM32H723 CMSIS and HAL sources.
- A PG7 LED blinky firmware.
- A USB DFU flashing target.

It does not yet provide:

- USB Host or TinyUSB.
- A USB clock tree configured for OTG operation.
- UAC microphone parsing.
- A DAC or ADC audio path.
- DMA audio buffers.
- A real-time audio task or thread.

## 4. Recommended hardware topology

### Board identification

Before wiring or coding, identify the exact board silkscreen and schematic. Generic listings often sell boards with hidden differences. Record:

- MCU part number.
- Exact USB connector and USB D+/D- routing.
- Whether an external USB PHY exists.
- Which pins are routed to USB D+/D-.
- Whether BOOT0 and RESET are available.
- Whether PA4/PA5 expose DAC outputs.
- Whether ADC/DAC pins conflict with the USB pins or onboard hardware.
- Crystal and board clock configuration.

Do not assume “USB-C”, “USB OTG”, or “H723” means the board exposes the USB host role. Document the board in an issue or this repository before proceeding.

### USB host port

For an H723 board, check the appropriate STM32 USB OTG controller and pins first:

- USB OTG HS may require an external ULPI PHY or internal PHY support, depending on the package and board.
- USB OTG FS commonly routes PA11/PA12, but verify from the schematic.
- Do not change USB roles at runtime until enumeration is stable.

The USB Host port must be powered by a valid 5 V supply and have enough current for the microphone. A bus-powered microphone may require more current than a USB cable or adapter supplies.

### First-stage analog output

For the lowest-risk bring-up, use the H723 internal DAC outputs:

- DAC1 OUT1 is commonly PA4.
- DAC1 OUT2 is commonly PA5.
- Verify the exact pins for the board schematic.

Use PA4 for mono if available. For a stereo DAC test, use PA4 and PA5. Add a 10 kHz or higher bandwidth probe or oscilloscope, because headphone/codec quality is not needed for the first test.

For the long-term mixer, an external I2S/SAI codec is preferable because the H723 internal DAC may not meet the final analog quality, channel count, output range, and EMC requirements.

### ADC loopback test

For loopback verification:

1. Start with a known-safe low-amplitude DAC output.
2. Route the DAC output through a divider/attenuator if necessary.
3. Feed it into an available ADC pin.
4. Never exceed the MCU's absolute ADC voltage limits.
5. Do not connect unbuffered headphone output or an instrument directly to an MCU ADC.

Good test points for AD range are often PA0-C or PC0-C, but the engineer must verify each pin from the board schematic and avoid USB/LED/boot pins.

## 5. Software dependencies

### Add TinyUSB as a submodule

TinyUSB is the Host/UAC implementation recommended for this prototype.

```bash
git submodule add https://github.com/hathach/tinyusb.git lib/tinyusb
git submodule update --init --recursive
```

Before building, verify the selected TinyUSB release has:

- STM32H7 or STM32H723 support.
- USB Host Audio support.
- The selected USB OTG port implementation.
- An example that uses UAC headphones/microphones.

Pin the submodule to a known tested commit. Do not update it during initial bring-up.

### Alternative

STM32Cube USB Host Middleware can implement UAC, but it is more coupled to Cube/HAL and may require more generated code. TinyUSB is preferred for this repository because it is portable and has clear host callback separation.

## 6. CMake integration

At minimum, CMake must add:

- TinyUSB sources for the core, host, UAC, and the selected H7 port.
- TinyUSB include directories.
- Board-specific USB configuration headers.
- DAC and ADC HAL sources.
- DMA and RCC HAL sources already used by the clock setup.
- `USE_TINYUSB` or another clearly named compile definition.

Example source organization:

```text
src/
  main.c
  board/
    board_init.c
    board_clock.c
    board_usb.c
  audio/
    audio_pipeline.c
    audio_ring.c
    usb_mic.c
    dac_output.c
    adc_meter.c
  system/
    stm32h7xx_it.c
    system_stm32h7xx.c
inc/
  board/
  audio/
  tusb_config.h
```

Keep generated USB callback code out of `main.c`. Place each subsystem behind a small header.

Before adding all sources, add one USB Host build to ensure it boots. Do not enable UAC, DAC, and the ADC in the first compile.

## 7. Clock configuration

The 64 MHz HSI-only startup clock is not sufficient for an audio prototype. Configure a board-verified system clock and USB clock.

Required measurements:

- Final SYSCLK.
- PLL1/PLL2/PLL3 settings.
- USB 48 MHz clock source.
- DAC trigger clock.
- ADC kernel clock.
- Timer/DMA trigger frequency.

At 48 kHz, generate a master audio block period. Start with 128 or 256 frames:

- 128 frames: 2.667 ms.
- 256 frames: 5.333 ms.

Start with 256 frames for bring-up if internal DAC and USB timing are stable. Move to 128 frames only after underrun counters remain zero.

A 48 kHz master clock should be used for:

- USB UAC decoding.
- DAC output blocks.
- ADC sample collection.
- Audio metering.

Do not directly mix USB isochronous packet timing with DAC DMA. USB packets can contain 47, 48, or 49 frames. Store PCM in a ring and apply a small resampler or compensation policy.

## 8. TinyUSB configuration

Create `inc/tusb_config.h` or a board configuration file and define the selected Host role.

Typical requirements:

- `CFG_TUSB_MCU = OPT_MCU_STM32H7`.
- `CFG_TUSB_RHPORT0_MODE = OPT_MODE_HOST` unless using the board's actual host port.
- `CFG_TUH_ENABLED = 1`.
- `CFG_TUH_AUDIO = 1`.
- `CFG_TUH_HUB = 1` only if a hub is required.
- `CFG_TUH_DEVICE_MAX = 1` initially.
- Endpoint and descriptor limits sized for one microphone.

Do not enable both `CFG_TUSB_OS` and a full RTOS unless a chosen OS is already implemented. For the first milestone, a bare-metal single-threaded plus DMA design is sufficient.

Port the TinyUSB board implementation for the exact H723 USB controller. Confirm from TinyUSB's checked-in STM32 board examples and headers rather than copying callback names by memory.

## 9. USB Host implementation

### Enumeration

Implement one USB host state machine:

```text
IDLE
  -> USB device attached
  -> wait for TinyUSB enumeration
  -> parse UAC interface and endpoints
  -> negotiate channel count/sample rate/format
  -> submit isochronous transfers
  -> STREAMING
  -> NO_MICROPHONE
  -> DISCONNECTED
```

The initial supported microphone profile should be intentionally narrow:

- USB Audio Class 1.
- One mono channel.
- 48 kHz.
- 16-bit PCM.
- AudioStreaming interface in the supported alternate setting.
- A non-blocking host receive callback.

A UAC 2 microphone can be added only after UAC 1 works. Stereo and 24-bit PCM are separate format branches.

### USB callbacks

The engineer must verify callback names and signatures in the installed TinyUSB version. At minimum, implement callbacks for:

- Device attach.
- Device detach.
- UAC interface mount/unmount.
- Received isochronous data.

The receive callback should:

1. Check microphone address and interface.
2. Validate the packet length.
3. Convert or copy PCM samples into a lock-free ring buffer.
4. Increment packet and frame counters.
5. Return immediately.

The receive callback must not:

- Call `HAL_Delay()`.
- Allocate memory.
- Parse descriptors.
- Start or stop a DAC.
- Acquire a blocking mutex.
- Print text through UART.
- Perform a long DSP operation.

TinyUSB's receive callback may indicate packet data length. Unused or truncated bytes must be counted and not silently interpreted.

## 10. Audio ring buffer

Use separate ring buffers for USB PCM and DAC output.

Example structure:

```c
#include <stdint.h>
#include <stddef.h>

#define AUDIO_SAMPLE_RATE 48000u
#define AUDIO_BLOCK_FRAMES 256u

#define PCM_RING_FRAMES 4096u

typedef struct
{
    int16_t samples[PCM_RING_FRAMES];
    volatile uint32_t read_index;
    volatile uint32_t write_index;
} pcm_ring16_t;

typedef struct
{
    uint32_t packet_count;
    uint32_t underrun_count;
    uint32_t overrun_count;
    uint32_t short_packet_count;
    uint32_t frame_count;
} audio_stats_t;

uint32_t pcm_ring_available(const pcm_ring16_t *ring);
uint32_t pcm_ring_space(const pcm_ring16_t *ring);
void pcm_ring_write(pcm_ring16_t *ring,
                    const int16_t *samples,
                    uint32_t frame_count);
uint32_t pcm_ring_read(pcm_ring16_t *ring,
                       int16_t *samples,
                       uint32_t frame_count);
```

Use one producer and one consumer, no multiple writers. Ring size should hold at least 40 to 80 ms in addition to DMA headroom:

- 4096 frames at 48 kHz is approximately 85 ms.

The ring is a prototype safety buffer. It is not a substitute for clock resampling or a tested latency target.

## 11. USB-to-DAC conversion

For an H723 DAC with 16-bit signed input:

```text
int16_t input -> unsigned DAC code
code = ((int32_t) sample + 32768) * 4095 / 65535
```

Clamp the result to 0 to 4095.

For mono DAC1:

1. Create a 256-frame `uint16_t` DAC buffer.
2. Fill half of the buffer from the ring.
3. Generate silence for the other half if the ring underruns.
4. Trigger DAC conversion from a timer or DMA reload event at 48 kHz.
5. Use DMA circular mode.
6. Maintain one active block and one next block.

Recommended DMA trigger frequency: 48 kHz.

Before loopback, add software amplitude limiting. For example, scale the PCM by 1/16 or 1/32 while creating the DAC code. USB microphones can be unexpectedly loud.

## 12. DAC DMA implementation

Use only one DAC conversion at first:

- DAC1 OUT1 on PA4.
- Timer 48 kHz trigger.
- DMA circular transfer.
- Single 16-bit data mode.

Pseudo-code:

```c
static uint16_t dac_frame[AUDIO_BLOCK_FRAMES];

static void dac_prepare_block(void)
{
    int16_t pcm[AUDIO_BLOCK_FRAMES];

    uint32_t count = pcm_ring_read(&usb_pcm,
                                   pcm,
                                   AUDIO_BLOCK_FRAMES);

    if (count < AUDIO_BLOCK_FRAMES)
    {
        audio_stats.underrun_count++;
    }

    for (uint32_t i = 0; i < count; i++)
    {
        int32_t attenuated = pcm[i] / 32;
        int32_t code = ((int32_t) attenuated + 32768) * 4095 / 65535;

        if (code < 0) code = 0;
        if (code > 4095) code = 4095;
        dac_frame[i] = (uint16_t) code;
    }

    for (uint32_t i = count; i < AUDIO_BLOCK_FRAMES; i++)
    {
        dac_frame[i] = 2048;
    }
}
```

The 48 kHz timer callback or DMA half-complete callback must fill the next DAC buffer block. Do not run USB, logging, or ring allocation from that interrupt.

For DMA correctness:

- Use STM32 cache attributes for any D-cache-coherent SRAM or external SDRAM buffer.
- Clean the D-cache before DAC DMA reads an output buffer.
- Invalidate the D-cache before CPU reads an ADC DMA input buffer.
- Prefer D2 SRAM or a non-cacheable DMA section if the linker supports it.
- Verify DMA source and destination widths.

## 13. ADC meter/loopback implementation

Use ADC DMA to sample one analog pin continuously.

Initial ADC settings:

- 48 kHz or at least 48 kHz effective sample rate.
- 16-bit or 12-bit resolution.
- DMA circular mode.
- Two half-complete blocks.
- One or two analog channels only.

For the loopback path:

1. DAC output feeds an attenuator/divider.
2. Divider output feeds one ADC channel.
3. ADC DMA writes samples to two ring/dual buffers.
4. A slow task calculates peak and RMS.
5. PG7 LED or UART reports every second.

Initial RMS meter:

```c
#include <stdint.h>
#include <math.h>

float adc_compute_rms(const uint16_t *samples, uint32_t count)
{
    float sum = 0.0f;

    for (uint32_t i = 0; i < count; i++)
    {
        float centered = (float) samples[i] - 2048.0f;
        sum += centered * centered;
    }

    return sqrtf(sum / (float) count);
}
```

Do not call `sqrtf()` in an interrupt. Compute RMS in a 1-second or 10 Hz diagnostic task.

If no USB microphone is available, test the DAC/ADC loopback with a generated sine buffer first. This distinguishes analog/DMA problems from USB problems.

## 14. Bare-metal scheduling

Use two execution domains:

### Interrupt/DMA domain

- USB Host isochronous callbacks.
- DAC DMA half-complete callbacks.
- ADC DMA half-complete callbacks.
- TinyUSB SOF or USB IRQ handling.

This domain may copy samples or set flags only.

### Main-loop domain

- TinyUSB `tuh_task()`.
- USB state monitoring.
- Ring-buffer population and underrun fill.
- Sine/DAC test output setup.
- Meter calculation.
- UART or LED diagnostics.
- USB reconnect handling.

If a FreeRTOS task is added later, keep audio production in one fixed priority task and USB stack in a separate task. Do not create audio processing inside TinyUSB callbacks.

## 15. Diagnostics

Expose these counters through a 1 Hz UART print or LED blink code:

- USB host mounted.
- USB microphone mounted.
- UAC format/rate/channel count.
- Packets received.
- Packet bytes total.
- Short/long packets.
- Missed SOFs.
- Ring available frames.
- Ring underrun count.
- Ring overrun count.
- DAC half-complete count.
- ADC RMS and peak.
- USB reconnect count.

UART diagnostics must remain outside 48 kHz audio callbacks.

Recommended console output:

```text
USB=1 UAC=1 packets=48000 short=0 underruns=0 overrun=0 ring=4096 dac_hz=48000 adc_rms=210
```

For headless bring-up, blink PG7 in patterns:

- Fast blink: USB not enumerated.
- Slow blink: USB attached but UAC not mounted.
- Solid: UAC streaming.
- Double blink: ring underrun or USB transfer error.

## 16. Bring-up sequence

### Phase A: Firmware and USB enumeration

1. Build the existing PG7 blinky.
2. Add USB clock initialization and TinyUSB Host.
3. Enumerate the board as a USB Host.
4. Insert only a USB keyboard or test mass device first.
5. Confirm attach/detach callbacks work.
6. Do not add UAC until attach/detach is stable.

If enumeration fails:

- Verify USB pins and connector.
- Verify USB clock exactly.
- Verify VBUS/host power topology.
- Measure D+/D- pull resistors and impedance.
- Check USB IRQ priority and vector registration.
- Confirm an STM32H7 USB port implementation is selected.

### Phase B: UAC mount

1. Connect one known 16-bit mono or stereo microphone.
2. Verify descriptors and alternate settings.
3. Select 48 kHz.
4. Count receive callbacks and packet lengths.
5. Print no more than once per second.

Reject or report unsupported formats instead of silently converting them.

### Phase C: Ring buffer

1. Copy PCM samples to the ring.
2. Run a dummy consumer that calculates peak/RMS.
3. Verify USB remains enumerated for at least 10 minutes.
4. Confirm ring never grows or shrinks continuously.

A slowly drifting USB clock may require 47/48/49 sample compensation. Do not add large silence insertion until packet behavior is known.

### Phase D: Internal DAC sine test

1. Generate a 1 kHz sine in software.
2. Output it through PA4 with timer/DMA at 48 kHz.
3. Verify output with an oscilloscope or ADC.
4. Confirm no DMA underrun or timer jitter.

### Phase E: USB microphone to DAC

1. Replace the sine source with ring-buffer reads.
2. Start with a 1/32 amplitude scale.
3. Verify speech or tone detection.
4. Record average and maximum ring fill.
5. Test disconnect and reconnect.

### Phase F: DAC-to-ADC loopback

1. Add an ADC pin and attenuator.
2. Capture ADC samples at 48 kHz.
3. Generate a sine through the USB-to-DAC path if possible.
4. Compare ADC RMS and frequency response.
5. Validate DMA cache handling.

## 17. Acceptance test procedure

Leave the system running for at least 30 minutes and record:

| Test | Pass condition |
|---|---|
| USB enum | Microphone appears before UAC timeout |
| UAC stream | Continuous 48 kHz packet reception |
| Ring stability | Read/write distance stays bounded |
| DAC output | Stable waveform; no DC or clipping |
| ADC loopback | ADC RMS tracks DAC output |
| Disconnect | Device removed without crashing |
| Reconnect | Same microphone returns to streaming |
| CPU load | Audio callback has bounded execution time |
| Underflows | Zero expected in steady state |
| Long run | No growth in underrun/overrun counters |

A human may not hear a 10 ms buffer issue, so counters and waveform timing must be used for validation.

## 18. Known failure patterns

### Device enumerates but no UAC stream

- Wrong alternate setting selected.
- Wrong endpoint direction or endpoint number.
- Unsupported format/rate.
- USB Host not scheduling isochronous transfers.
- SOF or USB clock issue.

### Pop/clock drift

- USB packet rate differs from 48 kHz local clock.
- Ring is not re-centering its fill level.
- Large ring reads/writes mismatch.
- Wrong stereo/mono byte conversion.
- Integer scaling uses incorrect endianness.

### DAC is silent

- Wrong DAC channel pin.
- Timer trigger not enabled.
- DMA source width mismatch.
- DMA source buffer not cache-cleaned.
- PA4 used by a conflicting onboard peripheral.

### ADC sees fixed/garbled values

- ADC/DAC voltages exceed limits.
- Missing ground reference.
- ADC DMA IRQ and D-cache invalidate timing wrong.
- DMA trigger does not match a stable sample clock.
- ADC resolution and DMA width mismatch.

### System hangs on USB disconnect

- State machine not clearing endpoints.
- Consumer assumes streaming forever.
- Blocking reconnect loop.
- UAC callback dereferences detached resources.

## 19. Files to add or modify

Required first milestone files:

```text
CMakeLists.txt
inc/tusb_config.h
src/board/board_clock.c
src/board/board_usb.c
src/audio/audio_ring.c
src/audio/usb_mic.c
src/audio/dac_output.c
src/audio/adc_meter.c
src/main.c
```

Update `README.md` with:

- Exact board model used.
- USB port used.
- TinyUSB submodule commit.
- Supported microphone profile.
- DAC output pin.
- ADC loopback pin.
- How to run enumerated and streaming states.

Do not add the following until this milestone passes:

- Guitar ADC input graph.
- USB Device UAC output.
- USB MIDI.
- Effects loading.
- RTOS tasks.
- File-system storage.
- UI controls.

## 20. Definition of done

This prototype is complete only when:

- The board boots from flash and has a visible health indication.
- One defined USB microphone is mounted and streams PCM.
- The ring buffer remains bounded for at least 30 minutes.
- The microphone audio appears at PA4 or the selected DAC output.
- The ADC loopback reads a corresponding analog signal.
- Underrun, overrun, short-packet, and disconnect counters are available.
- Reconnecting the microphone restores streaming without a reset.
- Hardware pins and TinyUSB commit are documented.
- The implementation is split into independently reviewable audio and USB modules.
