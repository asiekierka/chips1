local path = require("pl.path")
local stringx = require("pl.stringx")

function to_c_identifier(s)
	s = s:gsub("[^a-zA-Z0-9_]", "_")
	if not s:sub(1, 1):match("[_a-zA-Z]") then
		s = "_" .. s
	end
	return s
end

local args = {...}
local file <close> = io.open(args[1], "r")
local lines = file:lines()
local header = lines()

local games = {}

function apply_values(game, s)
	local parts = stringx.split(s, ",")
	for i = 1,#parts do
		local key, value = table.unpack(stringx.split(parts[i], "="))
		if key == "A" then
			game.keymap[1] = tonumber(value, 16)
		elseif key == "B" then
			game.keymap[2] = tonumber(value, 16)
		elseif key == "X1" then
			game.keymap[3] = tonumber(value, 16)
		elseif key == "X2" then
			game.keymap[4] = tonumber(value, 16)
		elseif key == "X3" then
			game.keymap[5] = tonumber(value, 16)
		elseif key == "X4" then
			game.keymap[6] = tonumber(value, 16)
		elseif key == "Y1" then
			game.keymap[7] = tonumber(value, 16)
		elseif key == "Y2" then
			game.keymap[8] = tonumber(value, 16)
		elseif key == "Y3" then
			game.keymap[9] = tonumber(value, 16)
		elseif key == "Y4" then
			game.keymap[10] = tonumber(value, 16)
		elseif key == "SCHIP" then
			game.flags = game.flags | 0x01
		elseif key == "DIAGONAL" then
			game.flags = game.flags | 0x02
		elseif key == "INV" then
			game.flags = game.flags | 0x80
		elseif key == "OPC" then
			game.opcodes = tonumber(value)
		elseif key == "BG" then
			game.bg = tonumber(value, 16)
		elseif key == "FG" then
			game.fg = tonumber(value, 16)
		end
	end
end

for line in lines do
	if line:sub(1,1) ~= "#" then
		local parts = stringx.split(line, "|")

		local filepath = parts[1]
		local basename = path.splitext(path.basename(filepath))
		local hpath = stringx.replace(filepath, ".", "_") .. ".h"

		local game = {
			filepath=filepath,
			hpath=hpath,
			name=parts[2],
			array_name=to_c_identifier(basename),
			keymap={0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF},
			bg=0x000,fg=0xFFF,
			opcodes=9,
			flags=0
		}
		if parts[1] == "NULL" then
			game.hpath = ""
			game.array_name = "NULL"
		end
		apply_values(game, header)
		if #parts >= 3 then
			apply_values(game, parts[3])
		end
		table.insert(games, game)
	end
end

for i,game in pairs(games) do
	if #game.hpath > 0 then
		print("#include \"" .. game.hpath .. "\"")
	end
end
print("")
print("#define LAUNCHER_ENTRIES_COUNT " .. #games)
print("")
print("static const launcher_entry_t __wf_rom launcher_entries[] = {")
for i,game in pairs(games) do
	print("    {")
	print("        " .. game.array_name .. ",")
	print("        " .. game.opcodes .. ",")
	print("        " .. game.flags .. ",")
	print("        {")
	for i=1,9 do print("            " .. game.keymap[i] .. ",") end
	print("            " .. game.keymap[10])
	print("        },")
	print("        " .. game.bg .. ",")
	print("        " .. game.fg .. ",")
	print("        \"" .. game.name .. "\"")
	if i == #games then print("    }") else print("    },") end
end
print("};")
