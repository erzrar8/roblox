--!strict
-- Fresh snow on the snow field: one tile per 4x4 cell, built by the map generator. Tiles a snowball
-- rolls over are hidden ("collected") and grow back after a while, so tracks show where balls went.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SnowballConfig"))

local TILE = 4
local REGROW_CHECK_INTERVAL = 0.5

local SnowLayer = {}

local grid: { [number]: { [number]: BasePart } } = {}
local regrowAt: { [BasePart]: number } = {}
local random = Random.new()

function SnowLayer.start(layer: Instance)
	for _, tile in layer:GetChildren() do
		if tile:IsA("BasePart") then
			local ix, iz = tile.Position.X // TILE, tile.Position.Z // TILE
			local column = grid[ix]
			if not column then
				column = {}
				grid[ix] = column
			end
			column[iz] = tile
		end
	end

	task.spawn(function()
		while true do
			task.wait(REGROW_CHECK_INTERVAL)
			local now = os.clock()
			for tile, time in regrowAt do
				if now >= time then
					tile.Transparency = 0
					regrowAt[tile] = nil
				end
			end
		end
	end)
end

-- Collects every fresh tile whose centre is within `radius` of `center` (horizontally); returns how many.
function SnowLayer.collect(center: Vector3, radius: number): number
	local collected = 0
	local now = os.clock()
	for ix = (center.X - radius) // TILE, (center.X + radius) // TILE do
		local column = grid[ix]
		if column then
			for iz = (center.Z - radius) // TILE, (center.Z + radius) // TILE do
				local tile = column[iz]
				if tile and not regrowAt[tile] then
					local dx = ix * TILE + TILE / 2 - center.X
					local dz = iz * TILE + TILE / 2 - center.Z
					if dx * dx + dz * dz <= radius * radius then
						tile.Transparency = 1
						regrowAt[tile] = now + random:NextNumber(Config.REGROW_MIN, Config.REGROW_MAX)
						collected += 1
					end
				end
			end
		end
	end
	return collected
end

return SnowLayer
