#ifndef _MAIN_H_
#define _MAIN_H_

#include <stdint.h>
#include <wonderful.h>

#define SCREEN_1 ((uint16_t*) 0x3000)
#define SCREEN_2 ((uint16_t*) 0x3800)

#define LAUNCHER_FLAG_SCHIP 0x01
#define LAUNCHER_FLAG_DIAGONALS 0x02

#define KEY_IDX_Y4    9
#define KEY_IDX_Y3    8
#define KEY_IDX_Y2    7
#define KEY_IDX_Y1    6
#define KEY_IDX_X4    5 // left
#define KEY_IDX_X3    4 // down
#define KEY_IDX_X2    3 // right
#define KEY_IDX_X1    2 // up
#define KEY_IDX_B     1
#define KEY_IDX_A     0

typedef struct {
    const void __wf_iram __far* data;
    uint8_t opcodes;
    uint8_t flags;
    uint8_t keymap[10];
    char game_name[24];
} launcher_entry_t;

#endif /* _MAIN_H_ */
