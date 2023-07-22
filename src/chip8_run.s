#include <wonderful.h>
#include "chip8.h"
    .arch   i186
    .code16
    .intel_syntax noprefix

    .global chip8_clear_display
    .global chip8_rng_tick
    .global chip8_run
    .global __chip8_di_regxy_ydh // chip8_display.s

chip8_clear_display:
    push es
    push di

    push ss
    pop es
    mov di, CHIP8_TILE_ADDRESS
    mov cx, 8 * 8 * 8
    xor ax, ax
    cld
    rep stosw

    pop di                                                                                                                                                                                                                                                                                                                                                        
    pop es
    ASM_PLATFORM_RET

    // Execution layout:
    // DS:BX = offset to chip8_state
    // SS:BP = offset to CHIP-8 RAM (0x0000:0x1000)
    // CX = opcode counter
    // SI = instruction pointer
    // AX, DX, DI, ES = free for opcode logic
chip8_run:
    push ds
    push es
    push ss
    push si
    push di
    push bp

    mov cx, dx
    mov bx, ax
    mov bp, [bx + CHIP8_STATE_RAM]
    mov si, [bx + CHIP8_STATE_PC]

chip8_run_opcode:
    mov ax, [bp + si]
    add si, 2
    xchg ah, al
    mov di, ax
    shr di, 11
    and di, 0xFFFE
    call cs:[di + chip8_opcode12_table]
    and si, 0xFFF
    loop chip8_run_opcode

chip8_run_opcode_early_return:
    mov [bx + CHIP8_STATE_PC], si

    pop bp
    pop di
    pop si
    pop ss
    pop es
    pop ds
    ASM_PLATFORM_RET

__chip8_di_regx:
    xchg ah, al
    mov di, ax
    and di, 0x000F
    ret

__chip8_di_regxy_ydh:
    push ax
    push ax
    mov di, ax
    shr di, 4
    and di, 0x000F
    mov dh, byte ptr [bx + di]
    pop di
    shr di, 8
    and di, 0x000F
    pop ax
    ret

chip8_todo:
    jmp chip8_todo

chip8_jump_offset:
    xor di, di
    xor dx, dx
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jz chip8_jump_offset_chip8
    mov dl, ah
    mov di, dx
    and di, 0x000F
chip8_jump_offset_chip8:
#endif
    mov dl, byte ptr [bx + di]
    add ax, dx
    and ax, 0xFFF
    mov si, ax
    ret

chip8_call:
    push bx
    mov dx, word ptr [bx + CHIP8_STATE_SP]
    add bx, dx
    mov word ptr [bx + CHIP8_STATE_STACK], si
    pop bx
    add dx, 2
    mov word ptr [bx + CHIP8_STATE_SP], dx
chip8_jump:
    mov si, ax
    ret

chip8_machine_routine:
chip8_machine_routine_ee:
    // Return to subroutine
    cmp ax, 0x00EE
    jne chip8_machine_routine_e0 // unlikely jump
    push bx
    mov dx, word ptr [bx + CHIP8_STATE_SP]
    sub dx, 2
    add bx, dx
    mov si, word ptr [bx + CHIP8_STATE_STACK]
    pop bx
    mov word ptr [bx + CHIP8_STATE_SP], dx
    ret
chip8_machine_routine_e0:
    // Clear display
    cmp ax, 0x00E0
    jne chip8_machine_routine_schip // unlikely jump
    push cx
    ASM_PLATFORM_CALL chip8_clear_display
    pop cx
    ret
chip8_machine_routine_schip:
#ifdef CHIP8_SUPPORT_SCHIP
    push ax
    and ax, 0xFFF0
    cmp ax, 0x00C0
    pop ax
    je chip8_scroll_down
chip8_machine_routine_fd:
    cmp ax, 0x00FD
    jne chip8_machine_routine_fe
    or byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_EXIT
    ret
chip8_machine_routine_fe:
    cmp ax, 0x00FE
    jne chip8_machine_routine_ff    
    and byte ptr [bx + CHIP8_STATE_PFLAG], ~CHIP8_PFLAG_HIRES
    ret
chip8_machine_routine_ff:
    cmp ax, 0x00FF
    jne chip8_machine_routine_xochip
    or byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_HIRES
    ret
chip8_machine_routine_xochip:
#ifdef CHIP8_SUPPORT_XOCHIP
    push ax
    and ax, 0xFFF0
    cmp ax, 0x00D0
    pop ax
    je chip8_scroll_up
#endif
#endif
    jmp chip8_todo

chip8_skip_eq:
    call __chip8_di_regx
    cmp byte ptr [bx + di], ah
__chip8_skip_eq_postcmp:
    jne L2
#ifdef CHIP8_SUPPORT_XOCHIP
    cmp word ptr [bp + si], 0xF000
    je chip8_skip_xo_f000
#endif
    add si, 2
L2:
    ret

#ifdef CHIP8_SUPPORT_XOCHIP
chip8_skip_xo_f000:
    add si, 4
    ret
#endif

chip8_skip_ne:
    call __chip8_di_regx
    cmp byte ptr [bx + di], ah
__chip8_skip_ne_postcmp:
    je L2
#ifdef CHIP8_SUPPORT_XOCHIP
    cmp word ptr [bp + si], 0xF000
    je chip8_skip_xo_f000
#endif
    add si, 2
L3:
    ret

chip8_skip_eq_xy:
    call __chip8_di_regxy_ydh
    cmp byte ptr [bx + di], dh
    jmp __chip8_skip_eq_postcmp

chip8_skip_ne_xy:
    call __chip8_di_regxy_ydh
    cmp byte ptr [bx + di], dh
    jmp __chip8_skip_ne_postcmp

chip8_register_set:
    call __chip8_di_regx
    mov byte ptr [bx + di], ah
    ret

chip8_register_add:
    call __chip8_di_regx
    add byte ptr [bx + di], ah
    ret

chip8_alu:
    call __chip8_di_regxy_ydh
    push di
    mov di, ax
    shl di, 1
    and di, 0x1E
    jmp cs:[di + chip8_alu_table]

chip8_alu_set:
    pop di
    mov byte ptr [bx + di], dh
    ret

chip8_alu_or:
    pop di
    or byte ptr [bx + di], dh
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jnz chip8_alu_or_schip
#endif
    mov byte ptr [bx + 0xF], 0
chip8_alu_or_schip:
    ret

chip8_alu_and:
    pop di
    and byte ptr [bx + di], dh
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jnz chip8_alu_and_schip
#endif
    mov byte ptr [bx + 0xF], 0
chip8_alu_and_schip:
    ret

chip8_alu_xor:
    pop di
    xor byte ptr [bx + di], dh
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jnz chip8_alu_xor_schip
#endif
    mov byte ptr [bx + 0xF], 0
chip8_alu_xor_schip:
    ret

chip8_alu_add:
    pop di
    add byte ptr [bx + di], dh
__chip8_alu_carry:
    mov al, 0
    adc al, 0
    mov byte ptr [bx + 0xF], al
    ret

chip8_alu_sub:
    pop di
    sub byte ptr [bx + di], dh
__chip8_alu_sub_carry:
    mov al, 1
    sbb al, 0
    mov byte ptr [bx + 0xF], al
    ret

chip8_alu_shr:
    pop di
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jz chip8_alu_shr_no_schip
    shr byte ptr [bx + di], 1
    jmp __chip8_alu_carry
chip8_alu_shr_no_schip:
#endif
    shr dh, 1
    mov byte ptr [bx + di], dh
    jmp __chip8_alu_carry

chip8_alu_sub_rev:
    pop di
    sub dh, byte ptr [bx + di]
    mov byte ptr [bx + di], dh
    jmp __chip8_alu_sub_carry

chip8_alu_shl:
    pop di
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jz chip8_alu_shl_no_schip
    shl byte ptr [bx + di], 1
    jmp __chip8_alu_carry
chip8_alu_shl_no_schip:
#endif
    shl dh, 1
    mov byte ptr [bx + di], dh
    jmp __chip8_alu_carry

chip8_alu_table:
    .word chip8_alu_set
    .word chip8_alu_or
    .word chip8_alu_and
    .word chip8_alu_xor
    .word chip8_alu_add
    .word chip8_alu_sub
    .word chip8_alu_shr
    .word chip8_alu_sub_rev
    .word chip8_todo
    .word chip8_todo
    .word chip8_todo
    .word chip8_todo
    .word chip8_todo
    .word chip8_todo
    .word chip8_alu_shl
    .word chip8_todo

chip8_index_set:
    and ax, 0xFFF
    mov word ptr [bx + CHIP8_STATE_INDEX], ax
    ret

chip8_key:
    call __chip8_di_regx
    push cx
    mov cl, [bx + di]
    and cl, 0x0F
    mov dx, 1
    shl dx, cl
    pop cx
    cmp ah, 0x9E
    jne chip8_key1
    test dx, [bx + CHIP8_STATE_KEY]
    jmp __chip8_skip_ne_postcmp
chip8_key1:
    cmp ah, 0xA1
    jne chip8_todo
    test dx, [bx + CHIP8_STATE_KEY]
    jmp __chip8_skip_eq_postcmp

chip8_misc_store_memory:
    push bx
    push cx
    xor cx, cx
    mov cl, ah
    and cl, 0xF
    inc cl
    mov di, [bx + CHIP8_STATE_INDEX]
    sub bx, di
chip8_misc_store_memory_loop:
    mov al, [bx + di]
    mov [bp + di], al
    inc di
    loop chip8_misc_store_memory_loop
    pop cx
    pop bx
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jnz chip8_misc_store_memory_schip
#endif
    mov [bx + CHIP8_STATE_INDEX], di
chip8_misc_store_memory_schip:
    ret

chip8_misc_load_memory:
    push bx
    push cx
    xor cx, cx
    mov cl, ah
    and cl, 0xF
    inc cl
    mov di, [bx + CHIP8_STATE_INDEX]
    sub bx, di
chip8_misc_load_memory_loop:
    mov al, [bp + di]
    mov [bx + di], al
    inc di
    loop chip8_misc_load_memory_loop
    pop cx
    pop bx
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr [bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jnz chip8_misc_load_memory_schip
#endif
    mov [bx + CHIP8_STATE_INDEX], di
chip8_misc_load_memory_schip:
    ret

#ifdef CHIP8_SUPPORT_SCHIP
chip8s_misc_store_memory_rpl:
    push cx
    xor cx, cx
    mov cl, ah
#ifdef CHIP8_SUPPORT_XOCHIP
    and cl, 0xF
#else
    and cl, 0x7
#endif
    inc cl
chip8s_misc_store_memory_rpl_loop:
    mov al, [bx + di]
    mov [bx + di + CHIP8_STATE_REGS_RPL], al
    inc di
    loop chip8s_misc_store_memory_rpl_loop
    pop cx
    ret

chip8s_misc_load_memory_rpl:
    push cx
    xor cx, cx
    mov cl, ah
#ifdef CHIP8_SUPPORT_XOCHIP
    and cl, 0xF
#else
    and cl, 0x7
#endif
    inc cl
    xor ax, ax
chip8s_misc_load_memory_rpl_loop:
    mov al, [bx + di + CHIP8_STATE_REGS_RPL]
    mov [bx + di], al
    inc di
    loop chip8s_misc_load_memory_rpl_loop
    pop cx
    ret
#endif

chip8_misc_bcd:
    call __chip8_di_regx
    mov al, [bx + di]
    mov di, [bx + CHIP8_STATE_INDEX]
    add di, 2
    and di, 0xFFF
    aam 10 // AL = mod, AH = div
    mov [bp + di], al
    xchg ah, al // AL = div
    dec di
    and di, 0xFFF
    aam 10
    mov [bp + di], al
    dec di
    and di, 0xFFF
    mov [bp + di], ah
    ret 

chip8_misc_get_key:
    call __chip8_di_regx
    mov al, [bx + CHIP8_STATE_LKEY]
    cmp al, 0xFF
    jne chip8_misc_get_key_got
    // Stall execution.
    pop ax
    sub si, 2
    jmp chip8_run_opcode_early_return
chip8_misc_get_key_got:
    mov [bx + di], al
    ret

chip8_rng_tick:
    mov bx, ax
    mov dx, [bx + CHIP8_STATE_RAND]
    mov ax, 25173
    mul dx
    add ax, 13849
    mov [bx + CHIP8_STATE_RAND], ax
    ASM_PLATFORM_RET

chip8_random:
    push ax
    call __chip8_di_regx
    mov ax, bx
    push bx
    push cx
    ASM_PLATFORM_CALL chip8_rng_tick
    pop cx
    pop bx
    pop ax
    and al, byte ptr [bx + CHIP8_STATE_RAND + 1]
    mov [bx + di], al
    ret

#ifdef CHIP8_SUPPORT_XOCHIP
chip8x_misc_index16_set:
    mov word ptr [bp + si], ax
    add si, 2
    ret
#endif

chip8x_misc_set_pitch:
    call __chip8_di_regx
    mov al, byte ptr [bx + di]
    mov byte ptr [bx + CHIP8_STATE_XO_PITCH], al
    ret

chip8_misc:
#ifdef CHIP8_SUPPORT_XOCHIP
    cmp ax, 0xF000
    je chip8x_misc_index16_set
#endif
    cmp al, 0x33
    je chip8_misc_bcd
    cmp al, 0x55
    je chip8_misc_store_memory
    cmp al, 0x65
    je chip8_misc_load_memory
    cmp al, 0x0A
    je chip8_misc_get_key
    cmp al, 0x07
    je chip8_misc_get_delay
    cmp al, 0x15
    je chip8_misc_set_delay
    cmp al, 0x18
    je chip8_misc_set_sound
    cmp al, 0x1E
    je chip8_misc_add_index
    cmp al, 0x29
    je chip8_misc_set_font
#ifdef CHIP8_SUPPORT_SCHIP
    cmp al, 0x75
    je chip8s_misc_store_memory_rpl
    cmp al, 0x85
    je chip8s_misc_load_memory_rpl
    cmp al, 0x30
    je chip8_misc_set_sfont
#endif
#ifdef CHIP8_SUPPORT_XOCHIP
    cmp al, 0x3A
    je chip8x_misc_set_pitch
#endif
    jmp chip8_todo

chip8_misc_get_delay:
    call __chip8_di_regx
    mov al, byte ptr [bx + CHIP8_STATE_DELAY]
    mov byte ptr [bx + di], al
    ret

chip8_misc_set_delay:
    call __chip8_di_regx
    mov al, byte ptr [bx + di]
    mov byte ptr [bx + CHIP8_STATE_DELAY], al
    ret

chip8_misc_set_sound:
    call __chip8_di_regx
    mov al, byte ptr [bx + di]
    mov byte ptr [bx + CHIP8_STATE_SOUND], al
    ret

chip8_misc_add_index:
    call __chip8_di_regx
    mov al, byte ptr [bx + di]
    xor ah, ah
    /* Disable contested overflow handling. */
    /* It's unknown which emulators, if any, worked this way. */
#if 1
    add word ptr [bx + CHIP8_STATE_INDEX], ax
#else
    mov dx, word ptr [bx + CHIP8_STATE_INDEX]
    add dx, ax
#ifdef CHIP8_SUPPORT_SCHIP
    test byte ptr[bx + CHIP8_STATE_PFLAG], CHIP8_PFLAG_SCHIP
    jnz chip8_misc_add_index_skip_overflow
#endif
    mov word ptr [bx + 0xF], 0x0
    cmp dx, 0x1000
    jae chip8_misc_add_index_overflow
    mov word ptr [bx + CHIP8_STATE_INDEX], dx
    ret
chip8_misc_add_index_overflow:
    and dx, 0xFFF
    mov word ptr [bx + CHIP8_STATE_INDEX], dx
    mov word ptr [bx + 0xF], 0x1
chip8_misc_add_index_skip_overflow:
#endif
    ret

chip8_misc_set_font:
    call __chip8_di_regx
    mov al, byte ptr [bx + di]
    and al, 0x0F
    mov dl, 5
    mul dl
    add ax, CHIP8_RAM_FONT_OFFSET
    mov word ptr [bx + CHIP8_STATE_INDEX], ax
    ret

#ifdef CHIP8_SUPPORT_SCHIP
chip8_misc_set_sfont:
    call __chip8_di_regx
    mov al, byte ptr [bx + di]
    and al, 0x0F
    mov dl, 10
    mul dl
    add ax, CHIP8_RAM_SFONT_OFFSET
    mov word ptr [bx + CHIP8_STATE_INDEX], ax
    ret
#endif

chip8_opcode12_table:
    .word chip8_machine_routine
    .word chip8_jump
    .word chip8_call
    .word chip8_skip_eq
    .word chip8_skip_ne
    .word chip8_skip_eq_xy
    .word chip8_register_set
    .word chip8_register_add
    .word chip8_alu
    .word chip8_skip_ne_xy
    .word chip8_index_set
    .word chip8_jump_offset
    .word chip8_random
    .word chip8_display
    .word chip8_key
    .word chip8_misc
