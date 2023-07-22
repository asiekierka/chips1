#ifndef _CHIP8_H_
#define _CHIP8_H_

#include "chip8_config.h"

#define CHIP8_RAM_FONT_OFFSET 0x0050
#define CHIP8_RAM_ADDRESS 0x1000
#define CHIP8_TILE_START 0
#define CHIP8_TILE_ADDRESS (0x2000 + ((CHIP8_TILE_START) * 16))
#define CHIP8_STACK_ENTRIES 16
#define CHIP8_STATE_REGS 0
#define CHIP8_STATE_PC 16
#define CHIP8_STATE_INDEX 18
#define CHIP8_STATE_DELAY 20
#define CHIP8_STATE_SOUND 21
#define CHIP8_STATE_LKEY  22
#define CHIP8_STATE_PFLAG 23
#define CHIP8_STATE_SP    24
#define CHIP8_STATE_KEY   26
#define CHIP8_STATE_RAND  28
#if defined(CHIP8_SUPPORT_XOCHIP)
#define CHIP8_STATE_REGS_RPL 32
#define CHIP8_STATE_STACK 48
#elif defined(CHIP8_SUPPORT_SCHIP)
#define CHIP8_STATE_REGS_RPL 32
#define CHIP8_STATE_STACK 40
#else
#define CHIP8_STATE_STACK 32
#endif

#define CHIP8_PFLAG_SCHIP  0x01
#define CHIP8_PFLAG_HIRES  0x02
#define CHIP8_PFLAG_XOCHIP 0x04
#define CHIP8_PFLAG_EXIT   0x80

#ifndef __ASSEMBLER__

#include <stdbool.h>
#include <stdint.h>

#define CHIP8_RAM ((uint8_t*) 0x1000)

typedef struct {
    uint8_t regs[16];
    uint16_t pc;
    uint16_t index;
    uint8_t delay;
    uint8_t sound;
    uint8_t lkey;
    uint8_t pflag;
    uint16_t sp;
    uint16_t key;
    uint32_t rand;
#if defined(CHIP8_SUPPORT_XOCHIP)
    uint8_t regs_rpl[16];
#elif defined(CHIP8_SUPPORT_SCHIP)
    uint8_t regs_rpl[8];
#endif
    uint16_t stack[CHIP8_STACK_ENTRIES];
} __attribute__((packed)) chip8_state_t;

extern chip8_state_t chip8_state;

// chip8.c

void chip8_init(void);

// chip8_run.s

void chip8_clear_display(void);
void chip8_rng_tick(chip8_state_t *state);
void chip8_run(chip8_state_t *state, uint16_t opcodes);

#endif

#endif /* _CHIP8_H_ */
