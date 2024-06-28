@ Non-standard string manipulation functions.
@ These functions are designed to make it easy to build strings in assembly code.
@ They are similar to, but not the same as, some of the string manipulation functions
@ in the C standard's menagerie.
@ These functions intentionally violate the AAPCS, so don't even try calling them from C code.
@
@ The convention in all of these functions is the same.
@ Registers r0--r2 are used for both input *and output*. (The output part is what breaks AAPCS,
@ which only allows a single return value. We have three.)
@ The parameter order is chosen to be similar to the parameter order of memset and memcpy.
@ * r0 is the address of the next character in the destination buffer
@ * r1 is the next value to write into the destination buffer
@ * r2 is the remaining space in the destination buffer

.syntax unified

.text

.global print_space
.global print_char
.thumb_func
.func
print_space:
    movs r1, #' '
    @ fall-through to print_char
print_char:                     @ dst, char, dstsz -> dst, (char or NUL), dstsz
    cmp  r2, #1                 @ -._ Out of space? (leave 1 extra byte for NUL char)
    bls  1f                     @ -'
    strb r1, [r0]               @ Copy to output
    adds r0, #1                 @ -._
    subs r2, #1                 @ -'  Advance dst
    bx   lr
1:  blo  2f                     @ Out of space. No room for NUL char?
    movs r1, #0                 @ -._
    strb r1, [r0]               @ -'  Write NUL char
    adds r0, #1                 @ -._
    subs r2, #1                 @ -'  Advance dst
2:  bx   lr
.endfunc


.global print_string
.thumb_func
.func
print_string:                   @ dst, src, dstsz -> dst, src, dstsz
    push {r4, lr}
    movs r4, r1                 @ Make r1 available for argument
2:  ldrb r1, [r4]               @ Get char from src
    cmp  r1, #0                 @ -._
    beq  1f                     @ -'  Reached end of src?
    bl   print_char
    cmp  r1, #0                 @ -._ Reached end of dst?
    beq  1f                     @ -'
    adds r4, #1                 @ Advance src
    b    2b
1:  movs r1, r4                 @ Put remainder of src (if any) back in original register
    pop  {r4, pc}
.endfunc

.global print_byte
.thumb_func
.func
print_byte:                     @ dst, byte, dstsz -> dst, (char or NUL), dstsz
    push {r4, r5, lr}
    uxtb r4, r1                 @ extract byte
    adr  r5, hexencode_table
    lsrs r1, r4, #4             @ high half-byte
    ldrb r1, [r5, r1]           @ look up in table
    bl   print_char
    movs r1, #0x0F              @ -._ low half-byte
    ands r1, r4                 @ -'
    ldrb r1, [r5, r1]           @ look up in table
    bl   print_char
    pop  {r4, r5, pc}
.endfunc

.balign 8
hexencode_table: .ascii "0123456789ABCDEF"

.global print_bytearray
.thumb_func
.func
print_bytearray:                @ dst, src, dstsz, srcsz -> dst, src, dstsz, srcsz
    push {r4, r5, lr}
    movs r4, r1                 @ Make r1 available for argument
    movs r5, r3                 @ Make r3 available for scratch
    beq  1f                     @ Is src empty?
3:  ldrb r1, [r4]               @ Get char from src
    bl   print_byte
    cmp  r1, #0                 @ -._ Reached end of dst?
    beq  2f                     @ -'
    adds r4, #1                 @ -._ Advance src
    subs r5, #1                 @ -'
    beq  2f                     @ Reached end of src?
    bl   print_space            @ Insert space between array elements
    b    3b
2:  movs r1, r4                 @ -._ Put remainder of src (if any) back in original registers
    movs r3, r5                 @ -'
1:  pop  {r4, r5, pc}
.endfunc

.global print_halfword
.thumb_func
.func
print_halfword:                 @ dst, halfword, dstsz -> dst, (char or NUL), dstsz
    push {r4, lr}
    movs r4, r1
    lsrs r1, r4, #8
    bl   print_byte
    movs r1, r4
    bl   print_byte
    pop  {r4, pc}
.endfunc

.global print_word
.thumb_func
.func
print_word:                     @ dst, word, dstsz -> dst, (char or NUL), dstsz
    push {r4, lr}
    movs r4, r1
    lsrs r1, r4, #24
    bl   print_byte
    lsrs r1, r4, #16
    bl   print_byte
    lsrs r1, r4, #8
    bl   print_byte
    movs r1, r4
    bl   print_byte
    pop  {r4, pc}
.endfunc
