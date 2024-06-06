.syntax unified


@ Messages are stored in a ring buffer.
@ To allow progress in writing new messages to the buffer, we try to keep the filled
@ part of the buffer to less than half the total buffer size.

.struct 0
morse_state.start:  .byte 0
morse_state.end:    .byte 0
morse_state.cur:    .byte 0
morse_state.letter: .byte 0
morse_state.pulse:  .byte 0
morse_state_len:

.bss
morse_buffer:       .zero 256
morse_state:        .zero morse_state_len

.text

.global morse_tx_handler
.thumb_func
.func
morse_tx_handler:
    ldr  r3, =morse_state

    @ Get existing pulse state.
    @ If pulse is unfinished, this will be >1.
    ldrb r0, [r3, #morse_state.pulse]
    cmp  r0, #1
    bhi  1f

    @ Pulse is finished. Get existing letter state.
    @ If letter has remaining pulses, this will be >1.
    @ If letter has remaining inter-letter space, this will be 1.
    ldrb r0, [r3, #morse_state.letter]
    cmp  r0, #1
    bhi  2f
    beq  3f
    
    @ Letter is finished. advance the cursor.
    ldrb r0, [r3, #morse_state.cur]
    ldrb r1, [r3, #morse_state.end]
    adds r2, r0, #1
    uxtb r2, r2
    cmp  r2, r1
    bne  4f
    ldrb r2, [r3, #morse_state.start]
4:  strb r2, [r3, #morse_state.cur]

    @ Get the letter at the old value of the cursor.
    @ If it's an actual letter, this will be >1.
    ldr  r1, =morse_buffer
    ldrb r0, [r1, r0]
    cmp  r0, #1
    bhi  2f
    @ The letter is actually a space, not a letter. Use an inter-word space. No need to update letter.
    movs r0, #(1 << 6 | 0b000000)
    b    1f

3:  @ All pulses in the letter have been transmitted. Clear the letter and use an inter-letter space.
    movs r0, #0
    strb r0, [r3, #morse_state.letter]
    movs r0, #(1 << 2 | 0b00)
    b    1f

2:  @ The letter has at least one remaining pulse. Store the remainder of the letter and get the pulse.
    lsrs r0, r0, #1
    strb r0, [r3, #morse_state.letter]
    movs r0, #(1 << 2 | 0b01)
    bcc  1f                             @ carry was set/cleared by lsrs
    movs r0, #(1 << 4 | 0b0111)

1:  @ Pulse is unfinished. Store the remainder of the pulse and transmit the current bit.
    lsrs r0, r0, #1
    strb r0, [r3, #morse_state.pulse]
    movs r0, #0
    bcc  5f                             @ carry was set/cleared by lsrs
    movs r0, #1
5:  ldr  r3, =(1 + morse_pin_write)
    bx   r3                             @ tail call
.endfunc

.global morse_init
.thumb_func
.func
morse_init:
    ldr  r3, =morse_buffer
    movs r0, #(1 << 4 | 0b0000)
    strb r0, [r3, #0]
    movs r0, #(1 << 1 | 0b0)
    strb r0, [r3, #1]
    movs r0, #(1 << 4 | 0b0010)
    strb r0, [r3, #2]
    movs r0, #(1 << 4 | 0b0010)
    strb r0, [r3, #3]
    movs r0, #(1 << 3 | 0b111)
    strb r0, [r3, #4]
    movs r0, 0
    strb r0, [r3, #5]
    movs r0, #(1 << 3 | 0b110)
    strb r0, [r3, #6]
    movs r0, #(1 << 3 | 0b111)
    strb r0, [r3, #7]
    movs r0, #(1 << 3 | 0b010)
    strb r0, [r3, #8]
    movs r0, #(1 << 4 | 0b0010)
    strb r0, [r3, #9]
    movs r0, #(1 << 3 | 0b001)
    strb r0, [r3, #10]
    movs r0, 0
    strb r0, [r3, #11]
    movs r0, 0
    strb r0, [r3, #12]
    movs r0, 0
    strb r0, [r3, #13]
    movs r0, 0
    strb r0, [r3, #14]
    movs r0, 0
    strb r0, [r3, #15]
    ldr  r3, =morse_state
    movs r0, #0
    strb r0, [r3, #morse_state.start]
    movs r0, #16
    strb r0, [r3, #morse_state.end]
    movs r0, #0
    strb r0, [r3, #morse_state.cur]
    movs r0, #0
    strb r0, [r3, #morse_state.letter]
    movs r0, #0
    strb r0, [r3, #morse_state.pulse]
    mov  r3, lr
    bx   r3
.endfunc

morse_conv_ranges:
    .byte 0x30
    .byte 0x39
    .byte 0x30
    .zero 1
    .byte 0x41
    .byte 0x5A
    .byte 0x41 - 10
    .zero 1
    .byte 0x61
    .byte 0x7A
    .byte 0x61 - 10
    .zero 1

@ Conversion table from ASCII to Morse.
@ This table contains all the digits 0-9 and letters A-Z, in order.
@ Dots are 0's, dashes are 1's.
@ Morse is a variable-length encoding, so we pad each symbol in this table with either a single 1
@ or a sequence of leading 0's followed by a 1.
@ Only what's remaining after the padding is the actual symbol.
@ To simplify the code used to transmit these symbols, the dot-dash pattern goes from
@ least-significant to most-significant bit, meaning they all appear reversed in this table.
morse_conv_bits:
    .byte 1<<5 | 0b11111    @ 0
    .byte 1<<5 | 0b11110    @ 1
    .byte 1<<5 | 0b11100    @ 2
    .byte 1<<5 | 0b11000    @ 3
    .byte 1<<5 | 0b10000    @ 4
    .byte 1<<5 | 0b00000    @ 5
    .byte 1<<5 | 0b00001    @ 6
    .byte 1<<5 | 0b00011    @ 7
    .byte 1<<5 | 0b00111    @ 8
    .byte 1<<5 | 0b01111    @ 9
    .byte 1<<2 | 0b10       @ A
    .byte 1<<4 | 0b0001     @ B
    .byte 1<<4 | 0b0101     @ C
    .byte 1<<3 | 0b001      @ D
    .byte 1<<1 | 0b0        @ E
    .byte 1<<4 | 0b0100     @ F
    .byte 1<<3 | 0b011      @ G
    .byte 1<<4 | 0b0000     @ H
    .byte 1<<2 | 0b00       @ I
    .byte 1<<4 | 0b1110     @ J
    .byte 1<<3 | 0b101      @ K
    .byte 1<<4 | 0b0010     @ L
    .byte 1<<2 | 0b11       @ M
    .byte 1<<2 | 0b01       @ N
    .byte 1<<3 | 0b111      @ O
    .byte 1<<4 | 0b0110     @ P
    .byte 1<<4 | 0b1011     @ Q
    .byte 1<<3 | 0b010      @ R
    .byte 1<<3 | 0b000      @ S
    .byte 1<<1 | 0b1        @ T
    .byte 1<<3 | 0b100      @ U
    .byte 1<<4 | 0b1000     @ V
    .byte 1<<3 | 0b110      @ W
    .byte 1<<4 | 0b1001     @ X
    .byte 1<<4 | 0b1101     @ Y
    .byte 1<<4 | 0b0011     @ Z
