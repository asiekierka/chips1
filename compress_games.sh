#!/bin/sh
rm cbin/*/*_lzsa.bin
for i in cbin/*/*.bin; do
	wf-lzsa -r -f 2 "$i" "${i%.*}"_lzsa.bin
done
