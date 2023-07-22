#!/bin/sh
wf-superfamiconv -i assets/chips1_bg.png -t cbin/chips1_bg_tiles.bin -m cbin/chips1_bg_map.bin -M ws -B 2 -T 167
wf-lzsa -r -f 2 cbin/chips1_bg_tiles.bin cbin/chips1_bg_tiles_lzsa.bin
wf-lzsa -r -f 2 cbin/chips1_bg_map.bin cbin/chips1_bg_map_lzsa.bin
