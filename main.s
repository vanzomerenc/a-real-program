.syntax unified

.section .vectors
    .word _estack           @  0    SP
    .word 1 + pc            @  1    PC
    .word 1 + fault         @  2    NMI
    .word 1 + fault         @  3    hard fault
    .word 1 + fault         @  4    -
    .word 1 + fault         @  5    -
    .word 1 + fault         @  6    -
    .word 1 + fault         @  7    -

    .word 1 + fault         @  8    -
    .word 1 + fault         @  9    -
    .word 1 + fault         @ 10    -
    .word 1 + fault         @ 11    SVCall
    .word 1 + fault         @ 12    -
    .word 1 + fault         @ 13    -
    .word 1 + fault         @ 14    PendSV
    .word 1 + fault         @ 15    SysTick

    .word 1 + fault         @ 16    DMA channel 0
    .word 1 + fault         @ 17    DMA channel 1
    .word 1 + fault         @ 18    DMA channel 2
    .word 1 + fault         @ 19    DMA channel 3
    .word 1 + fault         @ 20    -
    .word 1 + fault         @ 21    FTFA command complete and read collision
    .word 1 + fault         @ 22    PMC low-voltage detect, low-voltage warning
    .word 1 + fault         @ 23    LLWU Low Leakage Wakeup

    .word 1 + fault         @ 24    I2C0
    .word 1 + fault         @ 25    I2C1
    .word 1 + fault         @ 26    SPI0
    .word 1 + fault         @ 27    SPI1
    .word 1 + fault         @ 28    UART0
    .word 1 + fault         @ 29    UART1
    .word 1 + fault         @ 30    UART2
    .word 1 + fault         @ 31    ADC0

    .word 1 + fault         @ 32    CMP0
    .word 1 + fault         @ 33    TPM0
    .word 1 + fault         @ 34    TPM1
    .word 1 + fault         @ 35    TPM2
    .word 1 + fault         @ 36    RTC alarm
    .word 1 + fault         @ 37    RTC seconds
    .word 1 + fault         @ 38    PIT
    .word 1 + fault         @ 39    I2S0

    .word 1 + fault         @ 40    USB OTG
    .word 1 + fault         @ 41    DAC0
    .word 1 + fault         @ 42    TSI0
    .word 1 + fault         @ 43    MCG
    .word 1 + fault         @ 44    LPTMR0
    .word 1 + fault         @ 45    -
    .word 1 + fault         @ 46    Port Control Module pin detect (Port A)
    .word 1 + fault         @ 47    Port Control Module pin detect (Ports C and D)


@ Read section 27.3.1 VERY carefully.
@ It doesn't list the fields in order. Why, Freescale? WHY?
.section .flashconfig
    .skip 8, 0xFF           @ backdoor key
    .skip 4, 0xFF           @ flash protection
    .byte 0b11111110        @ FSEC: insecure
    .byte 0b11111010        @ FOPT: FAST_INIT | RESET_PIN_CFG | LPBOOT(2)       (OUTDIV1 set to div. by 2)
    .skip 2, 0xFF           @ reserved


@@@@@
@@@@@
@ Code!
@@@@@
@@@@@

@ This section exists just to try to fit some startup stuff in the gap before .flashconfig.
@ It'll come before .flashconfig in the finished hex file.
.section .startup


.thumb_func
fault:
    b fault

.thumb_func
pc:
    @@@@@
    @ Disable watchdog.
    @@@@@

    ldr  r0, =0x40048100    @ SIM_COPC
    movs r1, #0             @ disabled
    str  r1, [r0]

    @@@@@
    @ Configure MCG.
    @ We want to get to PLL Engaged External (yes, "PEE") mode.
    @ Read chapters 5, 24, and 25 from the KL26 manual.
    @ The diagram in chapter 5 is very helpful, as are the state diagram and example in chapter 24.
    @ Also, I've cheated and looked at the Teensy source code to make sure I get this right.
    @ Important notes:
    @ * Teensy uses a 16MHz crystal, not 4MHz.
    @ * Teensy needs 10pF internal oscillator load.
    @ * PLL (and thus MCGOUTCLK) *must* be 96MHz for USB to work to spec,
    @   since 48MHz USB clock has a fixed /2 divider from PLL.
    @ * 96MHz PLL and MCGOUTCLK also means we need to div. by 2 for core clock.
    @   I've chosen to set that through the FOPT option instead of here.
    @   Either way, that needs to be done before entering PEE mode.
    @@@@@


                            @ Configure external oscillator.
    ldr  r0, =0x40065000    @ OSC0_CR
    movs r1, #0b10001010    @ ERCLKEN | SC2P | SC8P         OSCCLK => OSCERCLK, use 10pF load for osc.
    strb r1, [r0, #0]

    ldr  r0, =0x40064000    @ MCG_x base

                            @ Transition from FEI to FBE mode.
    movs r1, #0b00100100    @ RANGE0(2) | EREFS0            very high freq. osc. (16MHz) => OSCCLK
    strb r1, [r0, #1]       @ MCG_C2
    movs r1, #0b10100000    @ CLKS(2) | FRDIV(4)            OSCCLK => MCGOUTCLK, OSCCLK / 512 (31.25kHz) => FLL input
    strb r1, [r0, #0]       @ MCG_C1
    movs r2, #0b00011110    @ IREFST | CLKST | OSCINIT0     status mask
_loop_MCG_FBE:
    ldrb r1, [r0, #6]       @ MCG_S
    ands r1, r2
    cmp  r1, #0b00001010    @ CLKST(2) | OSCINIT0           desired status
    bne  _loop_MCG_FBE

                            @ Transition from FBE to PBE mode.
    movs r1, #0b00000011    @ PRDIV0(3)                     OSCCLK / 4 (4MHz) => PLL input
    strb r1, [r0, #4]       @ MCG_C5
    movs r1, #0b01000000    @ PLLS                          PLL input * 24 (96MHz) => PLL output, switch from FLL to PLL
    strb r1, [r0, #5]       @ MCG_C6
    movs r2, #0b01100000    @ LOCK0 | PLLST                 status mask, desired set
_loop_MCG_PBE:
    ldrb r1, [r0, #6]       @ MCG_S
    tst  r1, r2
    beq  _loop_MCG_PBE

                            @ Transition from PBE to PEE mode.
    movs r1, #0b00100000    @ FRDIV(4)                      PLL => MCGOUTCLK, don't change FRDIV
    strb r1, [r0, #0]       @ MCG_C1
    movs r2, #0b00001100    @ CLKST                         status mask, desired set
_loop_MCG_PEE:
    ldrb r1, [r0, #6]       @ MCG_S
    tst  r1, r2
    beq  _loop_MCG_PEE

    @@@@@
    @ Configure module clocks.
    @@@@@

    ldr  r0, =0x40048000    @ SIM_x base + 0x1000

    ldr  r1, =0x00050000    @ USBSRC | PLLFLLSEL            PLL / 2 (48MHz) => USB clock
    str  r1, [r0, #4]       @ SIM_SOPT2
    ldr  r1, =0xF0040000    @ USBOTG                        USB clock gate enabled
    str  r1, [r0, #0x34]    @ SIM_SCGC4
    ldr  r1, =0x00000982    @ PORTC | <reserved fields>     PORTC clock gate enabled
    str  r1, [r0, #0x38]    @ SIM_SCGC5

    @@@@@
    @ Configure GPIO.
    @ Teensy's status LED is on pin 13, which is PTC6 (PORTC_6).
    @@@@@

    ldr  r0, =0xF8000080    @ FGPIOC_x base

    ldr  r1, =0x00000020    @ pin(5)
    str  r1, [r0, #0x14]    @ FGPIOC_PDDR

    @@@@@
    @ Configure pin functions.
    @@@@@

    ldr  r0, =0x4004B000    @ PORTC_PCRx base

    ldr  r1, =0x00000104    @ MUX(1) | SRE                  use as GPIO, limit slew rate
    str  r1, [r0, #0x14]    @ PORTC_PCR5

    @@@@@
    @ Blinky blinky.
    @@@@@

    ldr  r0, =0xF8000080
    ldr  r1, =0x00000020    @ pin(5)
    str  r1, [r0, #0x0C]    @ FGPIOC_PTOR
_loop_blink:
    ldr  r2, =2400000
_loop_delay:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    subs r2, #1
    bgt  _loop_delay
    str  r1, [r0, #0x0C]    @ FGPIOC_PTOR
    b    _loop_blink
