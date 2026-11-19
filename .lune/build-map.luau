--!strict
-- Regenerates map models into assets/map. Run from the repo root: `lune run build-map`
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Spawn = require("./map/Spawn")

local OUTPUT_DIR = "assets/map"

if not fs.isDir(OUTPUT_DIR) then
	fs.writeDir(OUTPUT_DIR)
end

local spawn = Spawn.build()
fs.writeFile(`{OUTPUT_DIR}/Spawn.rbxm`, roblox.serializeModel({ spawn }))

local parts = 0
for _, descendant in spawn:GetDescendants() do
	if descendant:IsA("BasePart") then
		parts += 1
	end
end
print(`Built {OUTPUT_DIR}/Spawn.rbxm ({parts} parts)`)
