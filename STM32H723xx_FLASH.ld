/*
 * Linker script for STM32H723VGTx (single core Cortex-M7)
 *   FLASH : 1024K @ 0x08000000
 *   RAM   : 320K AXI SRAM (D1) @ 0x24000000  <- main RAM
 *   DTCM  : 128K @ 0x20000000
 *   ITCM  : 64K  @ 0x00000000
 *   RAM_D2: 32K  @ 0x30000000
 *   RAM_D3: 8K   @ 0x38000000
 * Adjust FLASH length to 2048K if you have the H723ZG variant.
 */

ENTRY(Reset_Handler)

_estack = ORIGIN(DTCMRAM) + LENGTH(DTCMRAM);  /* stack in DTCM */

_Min_Heap_Size  = 0x4000;
_Min_Stack_Size = 0x2000;

MEMORY
{
    ITCMRAM  (xrw) : ORIGIN = 0x00000000, LENGTH = 64K
    DTCMRAM  (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
    FLASH    (rx)  : ORIGIN = 0x08000000, LENGTH = 1024K
    RAM_D1   (xrw) : ORIGIN = 0x24000000, LENGTH = 320K
    RAM_D2   (xrw) : ORIGIN = 0x30000000, LENGTH = 32K
    RAM_D3   (xrw) : ORIGIN = 0x38000000, LENGTH = 8K
}

SECTIONS
{
    .isr_vector :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector))
        . = ALIGN(4);
    } >FLASH

    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text*)
        *(.glue_7)
        *(.glue_7t)
        *(.eh_frame)
        KEEP(*(.init))
        KEEP(*(.fini))
        . = ALIGN(4);
        _etext = .;
    } >FLASH

    .rodata :
    {
        . = ALIGN(4);
        *(.rodata)
        *(.rodata*)
        . = ALIGN(4);
    } >FLASH

    .ARM.extab (READONLY) :
    {
        . = ALIGN(4);
        *(.ARM.extab* .gnu.linkonce.armextab.*)
        . = ALIGN(4);
    } >FLASH

    .ARM (READONLY) :
    {
        . = ALIGN(4);
        __exidx_start = .;
        *(.ARM.exidx*)
        __exidx_end = .;
        . = ALIGN(4);
    } >FLASH

    .preinit_array (READONLY) :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN(__preinit_array_start = .);
        KEEP(*(.preinit_array*))
        PROVIDE_HIDDEN(__preinit_array_end = .);
        . = ALIGN(4);
    } >FLASH

    .init_array (READONLY) :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN(__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array*))
        PROVIDE_HIDDEN(__init_array_end = .);
        . = ALIGN(4);
    } >FLASH

    .fini_array (READONLY) :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN(__fini_array_start = .);
        KEEP(*(SORT(.fini_array.*)))
        KEEP(*(.fini_array*))
        PROVIDE_HIDDEN(__fini_array_end = .);
        . = ALIGN(4);
    } >FLASH

    _sidata = LOADADDR(.data);

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data*)
        *(.RamFunc)
        *(.RamFunc*)
        . = ALIGN(4);
        _edata = .;
    } >RAM_D1 AT> FLASH

    . = ALIGN(4);
    .bss :
    {
        _sbss = .;
        __bss_start__ = _sbss;
        *(.bss)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
        __bss_end__ = _ebss;
    } >RAM_D1

    ._user_heap_stack :
    {
        . = ALIGN(8);
        PROVIDE(end = .);
        PROVIDE(_end = .);
        . = . + _Min_Heap_Size;
        . = . + _Min_Stack_Size;
        . = ALIGN(8);
    } >RAM_D1

    /DISCARD/ :
    {
        libc.a(*.o)
        libm.a(*.o)
        libgcc.a(*.o)
    }

    .ARM.attributes 0 : { *(.ARM.attributes) }
}
