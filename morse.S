#include "errno.h"

.syntax unified


@ Messages are stored in a ring buffer.
@ The 4 most recent messages in this buffer will be transmitted continuously.

.bss
.align 2
morse_buffer:       .zero 1 << 8        @ Making this exactly this long simplifies so many things.
.align 2
morse_state:        .zero morse_state_len

@ State/control information related to this buffer:
.struct 0
morse_state.end:    .byte 0     @ Location of the end of the most recently queued message.
                    .byte 0     @ -.
                    .byte 0     @  |- Locations of transitions between recently queued messages.
                    .byte 0     @ -'
morse_state.start:  .byte 0     @ Location of the start of the least recently queued message.
morse_state.cursor: .byte 0     @ Location of letter currently being transmitted within the buffer.
morse_state.letter: .byte 0     @ Pulses remaining in that letter.
morse_state.pulse:  .byte 0     @ Remainder of the current pulse.
morse_state_len:

.text

@ This is pushing the limits of the number of things I'm willing to do inside an interrupt handler.
@ We can get away with it because this handler can safely be run at a low priority, is run
@ relatively infrequently, and its own timing requirements are really, really forgiving.
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
    ldrb r0, [r3, #morse_state.cursor]
    adds r1, r0, #1
    uxtb r1, r1                         @ Wrap around ring buffer.
    ldrb r2, [r3, #morse_state.end]     @ -.
    cmp  r1, r2                         @  |- Did cursor hit end of most recent message?
    bne  4f                             @ -'
    ldrb r1, [r3, #morse_state.start]   @ Wrap to beginning of least recent message.
4:  strb r1, [r3, #morse_state.cursor]

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
5:  b    morse_pin_write                @ tail call
.endfunc

.global morse_init
.thumb_func
.func
morse_init:
    push {lr}
    ldr  r0, =morse_state
    movs r1, #0
    ldr  r2, =morse_state_len
    bl   memset
    ldr  r0, =morse_message
    ldr  r1, =morse_message_len
    bl   morse_write
    pop  {pc}
.endfunc

.global morse_write
.thumb_func
.func
morse_write:            @ message, length -> errorcode
    push {r4, r5, lr}
    ldr  r3, =morse_state
    ldr  r4, [r3, #morse_state.end]     @ Whole word; each byte locates end of a different message.
    movs r5, r0                         @ Make r0 available for return value.

    @ Check message length.
    @ Don't allow messages which are so long that they make it difficult to queue future messages.
    movs r0, #EMSGSIZE
    cmp  r1, #(256 / 5)                 @ 4 existing messages, plus one we're adding.
    bhi  1f

    @ Check for space in morse_buffer.
    movs r0, #EAGAIN
    ldrb r2, [r3, #morse_state.start]   @ -.
    subs r2, r2, r4                     @  |  (start - end) % 256, except 0
    subs r2, r2, #1                     @  |- How much of the buffer will NOT be repeated.
    uxtb r2, r2                         @  |
    adds r2, r2, #1                     @ -'
    cmp  r1, r2                         @ -._ Does new message fit?
    bhi  1f                             @ -'
    ldrb r2, [r3, #morse_state.cursor]  @ -.
    subs r2, r2, r4                     @  |  (cursor - end) % 256, except 0
    subs r2, r2, #1                     @  |- How much of the buffer is NOT queued already.
    uxtb r2, r2                         @  |  cursor may change at any time, but that is ok.
    adds r2, r2, #1                     @ -'
    cmp  r1, r2                         @ -._
    bhi  1f                             @ -'  Does new message fit?

    @ We know the new message will be added successfully.
    @ Update buffer start location promptly to reduce time wasted repeating old messages.
    @ It's unlikely, but if we're near the cursor this can be the difference between instantly
    @ seeing the new message, or spending several seconds (and a fair amount of buffer space)
    @ retransmitting existing messages.
    lsrs r2, r4, 24
    strb r2, [r3, #morse_state.start]

    @ Copy letters from message to morse_buffer, changing encoding along the way.
    push {r1, r6, r7}                   @ We need more registers!
    ldr  r7, =morse_buffer
    movs r6, r1
    b    2f
3:  ldrb r0, [r5, r6]                   @ Load byte from message.
    bl   morse_convert                  @ Convert encoding.
    adds r1, r4, r6                     @ -._ Location in buffer is (end + remaining_length) % 256
    uxtb r1, r1                         @ -'
    strb r0, [r7, r1]                   @ Store in buffer.
2:  subs r6, #1                         @ -._
    bhs  3b                             @ -'  Loop until no remaining length.
    pop  {r1, r6, r7}                   @ Restore registers clobbered by loop.

    @ Update morse_state.
    ldr  r3, =morse_state
    adds r1, r1, r4                     @ -._
    uxtb r1, r1                         @ -'  Calculate new end.
    lsls r4, r4, 8                      @ -.
    orrs r4, r4, r1                     @  |- Update buffer end location and transition locations.
    str  r4, [r3, #morse_state.end]     @ -'

    movs r0, #0
1:  pop  {r4, r5, pc}
.endfunc

.global morse_convert
.thumb_func
.func
morse_convert:           @ ascii_char -> morse_char
    cmp  r0, #0x80                      @ -._ Is valid ASCII char?
    bhs  1f                             @ -'
    cmp  r0, #0x30                      @ -._ Is char in alphanumeric range?
    blo  1f                             @ -'
    subs r0, r0, #0x30                  @ It is. Use table.
    cmp  r0, #0x30                      @ -._ Is char in lowercase-letter range?
    blo  2f                             @ -'
    subs r0, r0, #0x20                  @ It is. Convert to upper-case.
2:  ldr  r3, =morse_conv_bits           @ -._
    ldrb r0, [r3, r0]                   @ -'  Load from table.
    mov  pc, lr
1:  movs r0, #0                         @ Not in range.
    mov pc, lr
.endfunc

morse_message:
    .asciz "YES THIS IS MORSE CODE   "
morse_message_end:
morse_message_len = morse_message_end - morse_message

@ Conversion table from ASCII to Morse.
@ This table contains all the digits 0-9 and letters A-Z, in order, along with some zero padding
@ bytes (which become spaces) to simplify the code which does the conversion.
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
    .byte 0
    .byte 0

    .byte 0
    .byte 0
    .byte 0
    .byte 0

    .byte 0
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
    .byte 0

    .byte 0
    .byte 0
    .byte 0
    .byte 0
