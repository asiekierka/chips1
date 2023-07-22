#include <string.h>
#include <wonderful.h>
#include <ws.h>
#include <wsx/lzsa.h>
#include <wsx/planar_unpack.h>
#include "chip8.h"
#include "main.h"

#include "chips1_bg_map_lzsa_bin.h"
#include "chips1_bg_tiles_lzsa_bin.h"
#include "default_font_bin.h"

#include "game_list.inc"
#include "ws/display.h"
#include "ws/hardware.h"
#include "ws/keypad.h"
#include "ws/system.h"

uint8_t chip8_key_map[10];
uint8_t chip8_opcodes_per_tick;
uint8_t chip8_launcher_flags;

#define FONT_TILE_OFFSET (9 * 8)
#define SAFE_TILE_OFFSET (FONT_TILE_OFFSET + 95)

static const uint8_t __wf_rom chip8_buzzer_wave[] = {
	0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
	0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF
};

void wait_for_vblank(void) {
	while (inportb(IO_LCD_LINE) != 144) cpu_halt();	
}

__attribute__((interrupt))
void subdisp_font_line_handler(void) {
	if (inportb(IO_LCD_INTERRUPT) == 55) {
		outportw(IO_SCR_PAL(1), MONO_PAL_COLORS(0, 7, 0, 0));
		outportb(IO_LCD_INTERRUPT, 63);
	} else {
		outportw(IO_SCR_PAL(1), MONO_PAL_COLORS(7, 0, 0, 0));
		outportb(IO_LCD_INTERRUPT, 55);
	}

	ws_hwint_ack(HWINT_LINE);
}

void chips1_init_subdisp_font(void) {
	outportb(IO_DISPLAY_CTRL, inportb(IO_DISPLAY_CTRL) & ~DISPLAY_SCR2_ENABLE);
	outportw(IO_SCR_PAL(1), MONO_PAL_COLORS(7, 0, 0, 0));
	outportb(IO_SCR2_WIN_X1, 0);
	outportb(IO_SCR2_WIN_X2, 223);
	outportb(IO_SCR2_WIN_Y1, 0);
	outportb(IO_SCR2_WIN_Y2, 40 + 63);
	outportb(IO_SCR2_SCRL_X, 0);
	outportb(IO_SCR2_SCRL_Y, 0);
	ws_screen_fill_tiles(SCREEN_2, SCR_ENTRY_PALETTE(1) + FONT_TILE_OFFSET, 0, 0, 28, 32);
	outportb(IO_DISPLAY_CTRL, inportb(IO_DISPLAY_CTRL) | DISPLAY_SCR2_ENABLE);

	outportb(IO_LCD_INTERRUPT, 55);
	ws_hwint_set_handler(HWINT_IDX_LINE, subdisp_font_line_handler);
	ws_hwint_enable(HWINT_LINE);
}

void chips1_init_subdisp_game(void) {
	ws_hwint_disable(HWINT_LINE);
	outportb(IO_DISPLAY_CTRL, inportb(IO_DISPLAY_CTRL) & ~DISPLAY_SCR2_ENABLE);

	chip8_clear_display();
	outportb(IO_SCR2_WIN_X1, 48 + 0);
	outportb(IO_SCR2_WIN_X2, 48 + 127);
	outportb(IO_SCR2_WIN_Y1, 40 + 0);
	outportb(IO_SCR2_WIN_Y2, 40 + 63);
	outportb(IO_SCR2_SCRL_X, -48);
	outportb(IO_SCR2_SCRL_Y, -40);
	for (uint16_t i = 0; i < 32*32; i++) {
		SCREEN_2[i] = SCR_ENTRY_PALETTE(3 ^ (i & 1)) | (((i >> 1) & 0x7) << 3) | ((i >> 5) & 0x7);
	}

	outportb(IO_DISPLAY_CTRL, inportb(IO_DISPLAY_CTRL) | DISPLAY_SCR2_ENABLE);
}

void chips1_init_sound(void) {
	// configure wavetable
	outportb(IO_SND_WAVE_BASE, SND_WAVE_BASE(0x37C0));
	memcpy((uint8_t __wf_iram*) 0x37C0, chip8_buzzer_wave, 16);

	// configure sound chip
	outportb(IO_SND_CH_CTRL, 0);
	outportb(IO_SND_OUT_CTRL, SND_OUT_HEADPHONES_ENABLE | SND_OUT_SPEAKER_ENABLE | SND_OUT_DIVIDER_2);
	outportw(IO_SND_FREQ_CH1, 1840); // 440 Hz
	outportb(IO_SND_VOL_CH1, 0xFF);
}

void chips1_init_display(void) {
	// reclock LCD panel
	while (inportb(IO_LCD_LINE) != 1);
	outportb(IO_LCD_VTOTAL, 0xC8);
	outportb(IO_LCD_VSYNC, 0xC5);

	// configure palettes, memory
	ws_display_set_shade_lut(SHADE_LUT_DEFAULT);
	outportw(IO_SCR_PAL(0), MONO_PAL_COLORS(3, 6, 4, 1));
	outportw(IO_SCR_PAL(2), MONO_PAL_COLORS(7, 0, 7, 0));
	outportw(IO_SCR_PAL(3), MONO_PAL_COLORS(7, 7, 0, 0));
	outportb(IO_SCR_BASE, SCR1_BASE(0x3000) | SCR2_BASE(0x3800));
	outportw(IO_SCR1_SCRL_X, 0);
	outportw(IO_SCR2_SCRL_X, 0);

	// load default font
	wsx_planar_unpack(MEM_TILE(FONT_TILE_OFFSET), default_font_size, default_font, WSX_PLANAR_UNPACK_1BPP_TO_2BPP(0, 1));

	// configure screen 1
	wsx_lzsa2_decompress(MEM_TILE(SAFE_TILE_OFFSET), chips1_bg_tiles_lzsa);
	wsx_lzsa2_decompress(CHIP8_RAM, chips1_bg_map_lzsa);
	ws_screen_put_tiles(SCREEN_1, CHIP8_RAM, 0, 0, 28, 18);

	// configure screen 2 window
	outportb(IO_DISPLAY_CTRL, DISPLAY_SCR1_ENABLE | DISPLAY_SCR2_WIN_INSIDE);
}

static uint16_t keys_pressed, keys_held, keys_released;

static void update_keys(void) {
	uint16_t new_keys_held = ws_keypad_scan();
	keys_pressed = new_keys_held & (~keys_held); // held now but not before
	keys_released = ~new_keys_held & keys_held; // held before but not now
	keys_held = new_keys_held;
}

static uint16_t last_c8_key;

static void apply_key(uint16_t key_mask, uint8_t mapped_key) {
	uint16_t mapped_key_mask = 1 << (mapped_key & 0x0F);
	if ((((mapped_key & 0x10) ? keys_pressed : keys_held) & key_mask) == key_mask) {
		chip8_state.key |= mapped_key_mask;
	} else if (last_c8_key & mapped_key_mask) {
		// register key event on release
		chip8_state.lkey = mapped_key & 0x0F;
	}
}

void chips1_run(void) {
	while(true) {
		chip8_run(&chip8_state, chip8_opcodes_per_tick);

		// bump RNG
		chip8_rng_tick(&chip8_state);

		// update timers
		if (chip8_state.delay > 0) {
			chip8_state.delay--;
		}

		if (chip8_state.sound > 0) {
			outportb(IO_SND_CH_CTRL, SND_CH1_ENABLE);
			chip8_state.sound--;
		} else {
			outportb(IO_SND_CH_CTRL, 0);
		}

		update_keys();
		if (keys_released & KEY_START) {
			return;
		}

		last_c8_key = chip8_state.key;
		chip8_state.key = 0;
		chip8_state.lkey = 0xFF;
		for (uint8_t i = 2; i < 12; i++) {
			uint8_t mapped_key = chip8_key_map[i - 2];
			if (mapped_key < 0x80) {
				apply_key(1 << i, mapped_key);
			}
		}
		if (chip8_launcher_flags & LAUNCHER_FLAG_DIAGONALS) {
			apply_key(KEY_X1 | KEY_X4, 0x01);
			apply_key(KEY_X1 | KEY_X2, 0x03);
			apply_key(KEY_X3 | KEY_X4, 0x07);
			apply_key(KEY_X3 | KEY_X2, 0x09);
		}

		wait_for_vblank();	
	}
}

void chips1_launcher_run(const launcher_entry_t __wf_rom* entry) {
	chip8_init();
	wsx_lzsa2_decompress(CHIP8_RAM + 0x200, entry->data);
	memcpy(chip8_key_map, entry->keymap, 10);
	chip8_opcodes_per_tick = entry->opcodes;
	chip8_launcher_flags = entry->flags;
	chip8_state.pflag |= entry->flags & 0x01;
	chips1_run();
}

uint16_t game_index = 0;
#define GAME_SCROLL_Y_OFFSET 56

static void draw_launcher_entry(uint8_t y, int i) {
	const launcher_entry_t __far* entry = NULL;
	if (i >= 0 && i < LAUNCHER_ENTRIES_COUNT) entry = &launcher_entries[i];
	if (entry == NULL) {
		ws_screen_fill_tiles(SCREEN_2, SCR_ENTRY_PALETTE(1) + FONT_TILE_OFFSET, 0, y, 28, 1);
	} else {
		uint8_t len = strlen(entry->game_name);
		uint8_t start = (28 - len) >> 1;
		for (uint8_t x = 0; x < 28; x++) {
			uint8_t chr = 32;
			if (x >= start && x < start + len) {
				chr = entry->game_name[x - start];
			}
			ws_screen_put_tile(SCREEN_2, SCR_ENTRY_PALETTE(1) + FONT_TILE_OFFSET + chr - 32, x, y);
		}
	}
}

void chips1_select_game(void) {
	int16_t game_scroll_y = game_index * 8;
	int16_t game_scroll_y_camera = game_scroll_y;

	chips1_init_subdisp_font();
	outportb(IO_SCR2_SCRL_Y, game_scroll_y_camera - GAME_SCROLL_Y_OFFSET);

	while (true) {
		for (int y = -7; y <= 6; y++) {
			draw_launcher_entry((y + game_index) & 0x1F, y + game_index);
		}

		// bump RNG
		chip8_rng_tick(&chip8_state);

		wait_for_vblank();
		update_keys();
		if (keys_pressed & KEY_X1) {
			game_scroll_y_camera = game_scroll_y;
			game_scroll_y -= 8;
			if (game_scroll_y < 0) {
				game_scroll_y = (LAUNCHER_ENTRIES_COUNT - 1) * 8;
			}
		} else if (keys_pressed & KEY_X3) {
			game_scroll_y_camera = game_scroll_y;
			game_scroll_y += 8;
			if (game_scroll_y >= LAUNCHER_ENTRIES_COUNT * 8) {
				game_scroll_y = 0;
			}
		} else if (keys_pressed & KEY_A) {
			return;
		}

		outportb(IO_SCR2_SCRL_Y, game_scroll_y_camera - GAME_SCROLL_Y_OFFSET);
		int16_t new_game_scroll_y_camera = (game_scroll_y + game_scroll_y_camera) >> 1;
		if (new_game_scroll_y_camera == game_scroll_y_camera) {
			game_scroll_y_camera = game_scroll_y;
		} else {
			game_scroll_y_camera = new_game_scroll_y_camera;
		}
		game_index = game_scroll_y >> 3;
	}
}

int main(void) {
	chip8_state.rand = 1;

	outportb(IO_DISPLAY_CTRL, 0);
	ws_hwint_set_default_handler_vblank();
	ws_hwint_set(HWINT_VBLANK);
	cpu_irq_enable();
	
	chips1_init_display();
	chips1_init_sound();

	while(1) {
		wait_for_vblank();
		chips1_init_subdisp_font();
		chips1_select_game();

		while (true) {
			update_keys();
			if (keys_held == 0) break;
			wait_for_vblank();
		}
		chips1_init_subdisp_game();
		chips1_launcher_run(&launcher_entries[game_index]);
	}

	while(1);
}