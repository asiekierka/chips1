#include <wonderful.h>
#include "chip8.h"
    .arch   i186
    .code16
    .intel_syntax noprefix

    .global chip8_display

    // Execution layout:
    // DS:BX = offset to chip8_state
    // SS:BP = offset to CHIP-8 RAM (0x0000:0x1000)
chip8_display:
    push ds
    push cx
    push si
    push bp

    call __chip8_di_regxy_ydh
    mov dl, byte ptr [bx + di]
    and dx, 0x1F3F
    shl dx, 1
    // DL, DH = X, Y
    // convert to in-tile shift, index
    push ax
    // in-tile shift right = (X & 0xF)
    xor cx, cx
    mov cl, dl
    and cl, 0xF
    mov di, cx // DI = shift value
    // position = (Y << 1) + ((X >> 4) << 7)
    xor ax, ax
    mov al, dl
    and al, 0xF0
    shl ax, 3
    shl dh, 1
    or al, dh
    mov si, ax
    add si, CHIP8_TILE_ADDRESS
    pop cx
    and cx, 0x000F // CX = height
    jz chip8_display_done

    mov bp, CHIP8_RAM_ADDRESS
    add bp, word ptr [bx + CHIP8_STATE_INDEX]
    mov byte ptr [bx + 0xF], 0

    push ss
    push ds
    pop es
    pop ds
    // SS:BP = graphics source
    // DS:SI = graphics destination
    // ES:BX = state
    // CX = height
    // DI = shift value
    // AX, DX = unused
chip8_display_row:
    push bx
    mov al, byte ptr [bp]
    xor bx, bx
    inc bp
    mov bl, al
    and bl, 0xF
    mov dl, cs:[chip8_pxtbl_2x_right + bx]
    mov bl, al
    shr bl, 4
    mov dh, cs:[chip8_pxtbl_2x_right + bx]
    // DX = pixel value
    mov ax, dx
    xchg cx, di
    shr ax, cl
    push cx
    xor cl, 0xF
    inc cl
    shl dx, cl
    pop cx
    xchg cx, di
    // AL, AH, DL, DH = tile words to XOR
    pop bx
    push ax
    push dx
    and ax, [si]
    and dx, [si + 128]
    or ax, dx
    jz chip8_display_row_nobit
    mov byte ptr es:[bx + 0xF], 1
chip8_display_row_nobit:
    pop dx
    pop ax
    xor [si], ax
    xor [si + 128], dx
    xor [si + 2], ax
    xor [si + 128 + 2], dx
    add si, 4
    test si, 0x007F
    loopne chip8_display_row

chip8_display_done:
    pop bp
    pop si
    pop cx
    pop ds
    ret

chip8_pxtbl_2x_right:
    .byte 0x00
    .byte 0x03
    .byte 0x0C
    .byte 0x0F
    .byte 0x30
    .byte 0x33
    .byte 0x3C
    .byte 0x3F
    .byte 0xC0
    .byte 0xC3
    .byte 0xCC
    .byte 0xCF
    .byte 0xF0
    .byte 0xF3
    .byte 0xFC
    .byte 0xFF
