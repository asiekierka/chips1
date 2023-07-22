# Chips1

CHIP-8 emulator for the WonderSwan (80186-compatible CPU core, 2bpp 8x8 tiles). Pronounced "chips-one", or "chips-wan".

Built using [Wonderful](https://wonderful.asie.pl). Licensed under the terms of the MIT license.

## Building

Requires `target-wswan`, `wf-lua`, `wf-lzsa`, `wf-superfamiconv`.

* Edit `game_list.txt` to configure games.
* To add a new game, add a file to `cbin/N/` (any sub-directory `N`), then re-run `./compress_games.sh`.
* To update graphics (`assets/`): `./convert_assets.sh`.
* To build the ROM: `make`.

## Accuracy/Compatibility

### CHIP-8

| Feature/Quirk | Supported? |
| - | - |
| Standard opcodes | ✅ (except RCA 1802 execution) |
| Quirk: AND/OR/XOR flag reset | ✅ |
| Quirk: Load/store register changes I | ✅ |
| Quirk: Display wait | - |

### SUPER-CHIP 1.1

Note that the quirks specific to SUPER-CHIP 1.0 are not supported.

| Feature/Quirk | Supported? |
| - | - |
| Scroll down (00CN) | ✅ |
| Scroll left/right (00FC, 00FB) | - |
| Halt (00FD) | ✅ |
| Hi-resolution mode (00FE, 00FF) | ✅ |
| => Count collision rows (DXYN) | ✅ |
| Draw 16x16 sprite (DXY0) | ✅ |
| Large font (FX30) | ✅ |
| Load/store RPL user flag (FX75, FX85) | ✅ |
| Quirk: Load/store register | Leaves I unchanged |
| Quirk: BXNN jumps | ✅ |
| Quirk: SHL/SHR uses Vx | ✅ |
| Quirk: Screen not erased on mode change | ✅ |

### XO-CHIP

| Feature/Quirk | Supported? |
| - | - |
| Scroll up (00DN) | ✅ |
| Load/store register (5XY2, 5XY3) | ✅ |
| Large address space (F000 NNNN) | ✅ (memory limit, see below) |
| Two-plane drawing (FN01) | - (stub) |
| Custom audio samples (F002) | - (stub) |
| Pitch register (FX3A) | ✅ |
| Quirk: 16-register RPL user flag load/store | ✅ |
| Quirk: Mode change clears screen | ✅ |
| Quirk: Sprite draw wrapping | - |

### Octo

| Feature/Quirk | Supported? |
| - | - |
| Halt (0000) | - |
| Quirk: DXY0 draws low-res 16x16 sprite | - |
| Quirk: FX30 supports all hex characters | ✅ |

### Miscellanous

| Feature/Quirk | Supported? |
| - | - |
| Stack size | 16 entries |
| Maximum memory size (CHIP-8/SUPER-CHIP) | 4 KB |
| Maximum memory size (XO-CHIP | 45.5 KB (64 KB expected) |
