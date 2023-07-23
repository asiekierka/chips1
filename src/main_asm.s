#include <wonderful.h>
#include <ws.h>
#include "chip8.h"
    .arch   i186
    .code16
    .intel_syntax noprefix

    .global subdisp_font_line_handler

subdisp_font_line_handler:
    push ax
    in ax, IO_SCR_PAL_1
    xor ax, 0x7777
    out IO_SCR_PAL_1, ax
    in al, 0xa0
    test al, 0x80
    jz subdisp_font_line_handler_mono
subdisp_font_line_handler_color:
    push cx
    mov cx, 29
subdisp_font_line_handler_color_loop:
    loop subdisp_font_line_handler_color_loop
    pop cx
    xor word ptr ss:[0xFE20], 0x0AAA
    xor word ptr ss:[0xFE22], 0x0EEE
subdisp_font_line_handler_mono:
subdisp_font_line_handler_end:
    in al, IO_LCD_INTERRUPT
#ifdef EMULATOR_HACKS
    xor al, 8
#else
    xor al, 120
#endif
    out IO_LCD_INTERRUPT, al
    mov al, 0x10
    out IO_HWINT_ACK, al
    pop ax
    iret
