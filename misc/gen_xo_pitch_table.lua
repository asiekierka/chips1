print("const uint16_t __wf_rom chip8_xo_pitch_table[] = {")
for i=0,255 do
	-- that's samples per second
	lpitch = 4000 * (2 ^ ((i - 64) / 48.0))
	pitch = math.floor((2048 - (3072000 / (lpitch / 4))) + 0.5)
	if pitch < 0 then pitch = 0 end
	if pitch >= 2048 then pitch = 2047 end

	print(string.format("    %d, // (%d => %.02f)", pitch, i, lpitch))
end
print("};")
