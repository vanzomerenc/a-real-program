.syntax unified

.text

.global memcpy
.thumb_func
.func
1:  ldrb r3, [r1, r2]
    strb r3, [r0, r2]
memcpy:                 @ dst, src, count
    subs r2, #1
    bhs  1b
    mov  pc, lr
.endfunc

.global memset
.thumb_func
.func
1:  strb r1, [r0, r2]
memset:                 @ dst, val, count
    subs r2, #1
    bhs  1b
    mov  pc, lr
.endfunc
