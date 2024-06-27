#include "kl26.h"

.syntax unified

@ The number of USB endpoints to use.
@ Each endpoint has both a transmit and recieve direction, even if only one direction is used.
usb_num_endpts = 1

.struct 0
usb_bd.desc: .word 0
usb_bd.addr: .word 0
usb_bd_len:

usb_endpt_len = usb_bd_len * 4

.bss
.balign 512
usb_bdt:
    .zero usb_endpt_len * usb_num_endpts
usb_bdt_end:


.text

.global usb_init
.thumb_func
.func
usb_init:
    @ Set BDT address
    ldr  r0, =USB0_BDTPAGE1
    ldr  r1, =usb_bdt
    lsrs r1, r1, #8
    strb r1, [r0]
    lsrs r1, r1, #8
    strb r1, [r0, #(USB0_BDTPAGE2 - USB0_BDTPAGE1)]
    lsrs r1, r1, #8
    strb r1, [r0, #(USB0_BDTPAGE3 - USB0_BDTPAGE1)]

    @ Enable use of pull-up resistor.
    @ If USB0_OTGCTL.OTGEN = 0 (the default), this will also enable the resistor.
    ldr  r0, =USB0_CONTROL      @ the only thing in this entire register is the pull-up resistor
    movs r1, #0b00010000        @ DPPULLUPNONOTG
    strb r1, [r0]

    @ Enable USB module
    ldr  r0, =USB0_CTL          @ the actual control register for the USB module
    movs r1, #0b00000011        @ ODDRST | USBENSOFEN
    strb r1, [r0]

    @ Clear interrupts
    ldr  r0, =USB0_ISTAT
    movs r1, #0b11111111
    strb r1, [r0]
    strb r1, [r0, USB0_ERRSTAT - USB0_ISTAT]

    @ Take transciever out of suspend state
    ldr  r0, =USB0_USBCTRL      @ a control register for the USB transciever
    movs r1, #0
    strb r1, [r0]

    @ Enable reset interrupt
    ldr  r0, =USB0_INTEN
    movs r1, #0b00000001        @ USBRSTEN
    strb r1, [r0]
    ldr  r0, =NVIC_ISER
    ldr  r1, =(1 << 24)         @ USB OTG IRQ number
    str  r1, [r0]

    bx   lr
.endfunc
