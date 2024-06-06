/*  Copyright 2024 Chris Van Zomeren
 *  You may use and redistribute this under the terms of the "MIT License",
 *  which should be reproduced in the LICENSE file distributed with this code.
 *
 *  This linker script is for use with a Teensy LC, the SoC of which is a Freescale MKL26Z64VFT4.
 *  That SoC (and, by extension, the Teensy LC) is now impossible to get.
 */
MEMORY
{
    flash (rx) :    ORIGIN = 0,          LENGTH = 0x00010000
    ram (rw) :      ORIGIN = 0x1FFFF800, LENGTH = 0x00002000
}

SECTIONS
{
    .text : {
        KEEP(*(.vectors))
        . = 0x00000100;
        *(.startup)
        . = 0x00000400;
        KEEP(*(.flashconfig))
        . = 0x00000410;
        *(.text)
        *(.rodata)
    } > flash = 0xFF

    . = ALIGN(4);
    _sdata = .;
    .data : {
        *(.data)
    } > ram AT> flash
    _edata = .;
    _sdata_load = LOADADDR(.data);

    . = ALIGN(4);
    _sbss = .;
    .bss : {
        *(.bss)
    } > ram
    _ebss = .;

    _estack = ORIGIN(ram) + LENGTH(ram);
}
