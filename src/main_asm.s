#include <wonderful.h>
#include <ws.h>
#include "chip8.h"
    .arch   i186
    .code16
    .intel_syntax noprefix

    .global subdisp_font_line_handler

subdisp_font_line_handler:
    push ax
    in al, 0xa0
    test al, 0x80
    jz subdisp_font_line_handler_mono
subdisp_font_line_handler_color:
    xor word ptr ss:[0xFE20], 0x0FFF
    xor word ptr ss:[0xFE22], 0x0FFF
subdisp_font_line_handler_mono:
    in ax, IO_SCR_PAL_1
    xor ax, 0x7777
    out IO_SCR_PAL_1, ax
subdisp_font_line_handler_end:
    in al, IO_LCD_INTERRUPT
    xor al, 0x08
    out IO_LCD_INTERRUPT, al
    mov al, 0x10
    out IO_HWINT_ACK, al
    pop ax
    iret
