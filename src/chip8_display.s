#include <wonderful.h>
#include "chip8.h"
    .arch   i186
    .code16
    .intel_syntax noprefix

    .global chip8_display
    .global chip8_scroll_down
    .global chip8_scroll_up

#ifdef CHIP8_SUPPORT_SCHIP
chip8_scroll_prepare:
    push ss
    push ss
    pop es
    pop ds

    and al, 0x0F
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_HIRES
    jnz chip8_scroll_prepare_hires
    shl al, 1
chip8_scroll_prepare_hires:
    // DX=0x40-lines => ((lines^0x3F)+1)
    mov dx, ax
    xor dl, 0x3F
    inc dl

    // BX=step increment
    // from 0x00 to (0xFE-lines*2)
    // from (lines*2) to 0xFE
    mov bx, 0x100
    sub bx, ax
    sub bx, ax
    ret

    // DX = lines to copy
    // BX = pitch
    // Si, DI = areas
chip8_scroll_movsw:
    // DX=>CX = lines to copy
.rept 7
    mov cx, dx
    rep movsw
    add si, bx
    add di, bx
.endr
    mov cx, dx
    rep movsw
    ret

chip8_scroll_stosw:
    // DX=>CX = lines to copy
    xor ax, ax
.rept 7
    mov cx, dx
    rep stosw
    add di, bx
.endr
    mov cx, dx
    rep stosw
    ret

chip8_scroll_down:
    push bx
    push cx
    push si
    push ds
    push es

    // AX=lines
    call chip8_scroll_prepare

    // scroll down means: copy from 0x00..(0x7E-lines*2) to (lines*2)..0x7E
    // SI=0x7E-lines*2
    // DI=0x7E
    mov si, (CHIP8_TILE_ADDRESS + 0x7E)
    mov di, si
    sub si, ax
    sub si, ax

    // copy backwards
    std
    call chip8_scroll_movsw

    // fill empty space
    mov di, (CHIP8_TILE_ADDRESS)
    mov bx, 0x80
    sub bx, ax
    sub bx, ax
    mov dx, ax

    cld
    call chip8_scroll_stosw

chip8_scroll_finish:
    pop es
    pop ds
    pop si
    pop cx
    pop bx
    ret

#ifdef CHIP8_SUPPORT_XOCHIP
chip8_scroll_up:
    push bx
    push cx
    push si
    push ds
    push es

    // AX=lines
    call chip8_scroll_prepare

    // scroll up means: copy from 0x00..(lines*2) to (0x7E-lines*2)..0x7E
    // SI=lines*2
    // DI=0x00
    mov si, (CHIP8_TILE_ADDRESS)
    mov di, si
    add si, ax
    add si, ax

    // copy forwards
    cld
    call chip8_scroll_movsw

    // fill empty space
    shl ax, 1
    mov di, (CHIP8_TILE_ADDRESS + 0x80)
    sub di, ax
    mov bx, 0x80
    sub bx, ax
    shr ax, 1
    mov dx, ax

    call chip8_scroll_stosw

    jmp chip8_scroll_finish
#endif
#endif

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
#ifdef CHIP8_SUPPORT_SCHIP
    and dx, 0x3F7F
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_HIRES
    jnz chip8_display_xy_done
chip8_display_xy_lores:
#endif
    and dx, 0x1F3F
    shl dx, 1
chip8_display_xy_done:
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

    mov bp, CHIP8_RAM_ADDRESS
    add bp, word ptr [bx + CHIP8_STATE_INDEX]
    mov byte ptr [bx + 0xF], 0

    push ss
    push ds
    pop es
    pop ds

#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_HIRES
    jnz chip8_display_hires
#endif

    pop cx
    and cx, 0x000F // CX = height
    jz chip8_display_done

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
    xor [si + 2], ax
    cmp si, (CHIP8_TILE_ADDRESS + 128*7)
    jae chip8_display_row_nobit_lastrow
    xor [si + 128], dx
    xor [si + 128 + 2], dx
chip8_display_row_nobit_lastrow:
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

#ifdef CHIP8_SUPPORT_SCHIP
    // TODO: Optimize. We can use 8-bit shifts here.
chip8_display_hires:
    pop cx
    and cx, 0x000F // CX = height
    jz chip8_display_hires_16x16
    
    // SS:BP = graphics source
    // DS:SI = graphics destination
    // ES:BX = state
    // CX = height
    // DI = shift value
    // AX, DX = unused
chip8_display_hires_row:
    push bx
    xor dx, dx
    mov dh, byte ptr [bp]
    inc bp
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
    jz chip8_display_hires_row_nobit
    inc byte ptr es:[bx + 0xF]
chip8_display_hires_row_nobit:
    pop dx
    pop ax
    xor [si], ax
    cmp si, (CHIP8_TILE_ADDRESS + 128*7)
    jae chip8_display_hires_row_nobit_lastrow
    xor [si + 128], dx
chip8_display_hires_row_nobit_lastrow:
    add si, 2
    test si, 0x007F
    loopne chip8_display_hires_row
    add byte ptr es:[bx + 0xF], cl

    jmp chip8_display_done

chip8_display_hires_16x16:
    // SS:BP = graphics source
    // DS:SI = graphics destination
    // ES:BX = state
    // CX = height
    // DI = shift value
    // AX, DX = unused
    mov cx, 16
chip8_display_hires_16x16_row:
    push bx
    mov dx, word ptr [bp]
    xchg dh, dl
    add bp, 2
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
    jz chip8_display_hires_16x16_row_nobit
    inc byte ptr es:[bx + 0xF]
chip8_display_hires_16x16_row_nobit:
    pop dx
    pop ax
    xor [si], ax
    cmp si, (CHIP8_TILE_ADDRESS + 128*7)
    jae chip8_display_hires_16x16_row_nobit_lastrow
    xor [si + 128], dx
chip8_display_hires_16x16_row_nobit_lastrow:
    add si, 2
    test si, 0x007F
    loopne chip8_display_hires_16x16_row
    add byte ptr es:[bx + 0xF], cl

    jmp chip8_display_done
#endif
