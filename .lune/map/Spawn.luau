--!strict
-- Spawn island: snowy voxel plateau, tiled plaza with the SpawnLocation, giant snowball statue
-- and a bridge leading to the (not yet built) Zone 1 gate.
--
-- Grid: 1 voxel = 4 studs, cell (x, z) covers X in [4x, 4x+4] and Z in [4z, 4z+4]. Ground top of
-- height level h is at Y = 4h. Players spawn facing -Z, so the gate sits at the -Z end.

local roblox = require("@lune/roblox")
local Builder = require("./Builder")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local UDim2 = roblox.UDim2
local Enum = roblox.Enum

local Palette = Builder.Palette
local block, box, container = Builder.block, Builder.box, Builder.container

local VOXEL = 4
local GRID_MIN, GRID_MAX = -18, 17
local ISLAND_RADIUS = 17.6
local ISLAND_BOTTOM = -12
local CAP = 1.5
local TILE_HEIGHT = 0.4
local BRIDGE_START, BRIDGE_END = -19, -26
local SEED = 2026

type Cell = { h: number, kind: string }

local function isPlaza(x: number, z: number): boolean
	return x >= -5 and x <= 4 and z >= -5 and z <= 4
end

local function isPath(x: number, z: number): boolean
	return x >= -2 and x <= 1 and z < -5 and z >= BRIDGE_END
end

-- Corridor through the rim towards the gate, kept flat and free of decorations.
local function isCorridor(x: number, z: number): boolean
	return x >= -3 and x <= 2 and z < -5
end

local function isStatueArea(x: number, z: number): boolean
	return x >= 6 and x <= 11 and z >= -3 and z <= 2
end

local function islandDistance(x: number, z: number): number
	-- Superellipse: a square island with rounded corners.
	return (math.abs(x + 0.5) ^ 4 + math.abs(z + 0.5) ^ 4) ^ 0.25
end

local function cellCenter(x: number, z: number, y: number): any
	return Vector3.new(x * VOXEL + VOXEL / 2, y, z * VOXEL + VOXEL / 2)
end

local function buildHeightmap(): { [number]: { [number]: Cell } }
	local rng = Builder.rng(SEED)
	-- Height noise in 3x3 chunks gives chunky terraces instead of single-cell speckle.
	local chunkNoise: { [string]: number } = {}
	local function noise(x: number, z: number): number
		local key = `{x // 3},{z // 3}`
		local value = chunkNoise[key]
		if value == nil then
			value = rng.next()
			chunkNoise[key] = value
		end
		return value
	end

	local cells = {}
	for x = GRID_MIN, GRID_MAX do
		cells[x] = {}
		for z = GRID_MIN, GRID_MAX do
			local d = islandDistance(x, z)
			if d <= ISLAND_RADIUS then
				local n = noise(x, z)
				local h
				if d > 14.8 then
					h = if n < 0.4 then 3 else 2
				elseif d > 12.6 then
					h = if n < 0.3 then 2 else 1
				else
					h = if d > 9 and n > 0.85 then 1 else 0
				end

				if isCorridor(x, z) or isStatueArea(x, z) then
					h = 0
				elseif x >= -4 and x <= 3 and z < -5 then
					h = math.min(h, 1)
				end

				local kind = if isPlaza(x, z) or isPath(x, z) then "stone" else "snow"
				cells[x][z] = { h = if kind == "stone" then 0 else h, kind = kind }
			end
		end
	end
	return cells
end

local function buildGround(parent: any, cells: { [number]: { [number]: Cell } })
	local function keyAt(x: number, z: number): string?
		local column = cells[x]
		local cell = column and column[z]
		return cell and `{cell.kind}:{cell.h}`
	end

	for _, rect in Builder.greedyRects(GRID_MIN, GRID_MAX, GRID_MIN, GRID_MAX, keyAt) do
		local cell = cells[rect.x0][rect.z0]
		local top = cell.h * VOXEL
		local x0, x1 = rect.x0 * VOXEL, (rect.x1 + 1) * VOXEL
		local z0, z1 = rect.z0 * VOXEL, (rect.z1 + 1) * VOXEL
		box(parent, Vector3.new(x0, ISLAND_BOTTOM, z0), Vector3.new(x1, top - CAP, z1), Palette.Dirt, { name = "Dirt" })
		if cell.kind == "snow" then
			box(parent, Vector3.new(x0, top - CAP, z0), Vector3.new(x1, top, z1), Palette.Snow, { name = "Snow" })
		else
			box(parent, Vector3.new(x0, top - CAP, z0), Vector3.new(x1, top, z1), Palette.Grout, { name = "Grout" })
		end
	end
end

local function buildTiles(parent: any)
	local rng = Builder.rng(SEED + 1)
	local function tile(x: number, z: number, color: any)
		block(parent, Vector3.new(3.6, TILE_HEIGHT, 3.6), CFrame.new(cellCenter(x, z, TILE_HEIGHT / 2)), color, { name = "Tile" })
	end

	for x = -5, 4 do
		for z = -5, 4 do
			local onEdge = x == -5 or x == 4 or z == -5 or z == 4
			local pathOpening = z == -5 and x >= -2 and x <= 1
			if onEdge and not pathOpening then
				tile(x, z, Palette.TileDark)
			else
				tile(x, z, if rng.chance(0.25) then Palette.TileAlt else Palette.Tile)
			end
		end
	end

	for z = -6, BRIDGE_END, -1 do
		for x = -2, 1 do
			if x == -2 or x == 1 then
				tile(x, z, Palette.TileDark)
			else
				tile(x, z, if rng.chance(0.25) then Palette.TileAlt else Palette.Tile)
			end
		end
	end
end

local function buildSpawnLocation(parent: any)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.6, 8)
	-- Identity rotation: players spawn looking down -Z, towards the gate.
	spawn.CFrame = CFrame.new(0, TILE_HEIGHT + 0.3, 0)
	spawn.Color = Palette.Spawn
	spawn.Material = Enum.Material.Plastic
	spawn.TopSurface = Enum.SurfaceType.Studs
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = parent
end

local function buildLamp(parent: any, base: any)
	local lamp = container("Model", "Lamp", parent)
	block(lamp, Vector3.new(2, 1, 2), CFrame.new(base + Vector3.new(0, 0.5, 0)), Palette.LampPost, { name = "Base" })
	block(lamp, Vector3.new(0.8, 7, 0.8), CFrame.new(base + Vector3.new(0, 4.5, 0)), Palette.LampPost, { name = "Post" })
	local head = block(lamp, Vector3.new(1.8, 1.8, 1.8), CFrame.new(base + Vector3.new(0, 8.9, 0)), Palette.LampLight, {
		name = "Light",
		material = Enum.Material.Neon,
		studs = false,
	})
	block(lamp, Vector3.new(2.6, 0.6, 2.6), CFrame.new(base + Vector3.new(0, 10.1, 0)), Palette.Snow, { name = "Cap" })

	local light = Instance.new("PointLight")
	light.Color = Palette.LampLight
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = head
end

local function buildBridgeAndGate(parent: any)
	local bridge = container("Model", "Bridge", parent)
	local zMin, zMax = BRIDGE_END * VOXEL, (BRIDGE_START + 1) * VOXEL
	box(bridge, Vector3.new(-8, -4, zMin), Vector3.new(8, -CAP, zMax), Palette.Dirt, { name = "Dirt" })
	box(bridge, Vector3.new(-8, -CAP, zMin), Vector3.new(8, 0, zMax), Palette.Grout, { name = "Grout" })
	for _, side in { -1, 1 } do
		local xInner, xOuter = 8 * side, 12 * side
		local xMin, xMax = math.min(xInner, xOuter), math.max(xInner, xOuter)
		box(bridge, Vector3.new(xMin, -4, zMin), Vector3.new(xMax, 1, zMax), Palette.Dirt, { name = "RailDirt" })
		box(bridge, Vector3.new(xMin, 1, zMin), Vector3.new(xMax, 2.5, zMax), Palette.Snow, { name = "RailSnow" })
	end

	local gate = container("Model", "Zone1Gate", parent)
	local gateZ = zMin + VOXEL / 2
	for _, x in { -10, 10 } do
		for level = 0, 3 do
			local color = if level % 2 == 0 then Palette.Ice else Palette.IceDark
			block(gate, Vector3.new(4, 4, 4), CFrame.new(x, 2.5 + level * 4 + 2, gateZ), color, { name = "Pillar", reflectance = 0.1 })
		end
	end
	for i = 0, 5 do
		local color = if i % 2 == 0 then Palette.IceDark else Palette.Ice
		block(gate, Vector3.new(4, 4, 4), CFrame.new(-10 + i * 4, 20.5, gateZ), color, { name = "Lintel", reflectance = 0.1 })
	end
	box(gate, Vector3.new(-12.5, 22.5, gateZ - 2.5), Vector3.new(12.5, 24, gateZ + 2.5), Palette.Snow, { name = "Cap" })

	-- Invisible wall until Zone 1 exists; later this becomes the zone unlock barrier.
	block(gate, Vector3.new(16, 18, 1), CFrame.new(0, 9.5, gateZ), Palette.Ice, {
		name = "ZoneBarrier",
		transparency = 1,
		studs = false,
	})

	local sign = block(gate, Vector3.new(14, 4.5, 0.5), CFrame.new(0, 15.75, gateZ + 2.25), Palette.Sign, { name = "Sign" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces +Z, towards the spawn
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = "ZONE 1\nCOMING SOON"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 30, 60)
	label.Parent = gui
end

-- Voxel sphere made of 2-stud cubes, merged into one part per row.
local function buildSnowballStatue(parent: any)
	local statue = container("Model", "SnowballStatue", parent)
	local rng = Builder.rng(SEED + 2)
	local center = Vector3.new(36, 13, 0)
	box(statue, Vector3.new(28, 0, -8), Vector3.new(44, 1, 8), Palette.Grout, { name = "Pedestal" })
	box(statue, Vector3.new(29, 1, -7), Vector3.new(43, 2, 7), Palette.TileDark, { name = "Pedestal" })

	local unit, radius = 2, 5.5
	for j = -6, 5 do
		for k = -6, 5 do
			local remaining = radius * radius - (j + 0.5) ^ 2 - (k + 0.5) ^ 2
			if remaining > 0 then
				local halfCount = math.floor(math.sqrt(remaining) + 0.5)
				if halfCount > 0 then
					local color = if rng.chance(0.2) then Palette.SnowShade else Palette.Snow
					block(
						statue,
						Vector3.new(halfCount * 2 * unit, unit, unit),
						CFrame.new(center + Vector3.new(0, (j + 0.5) * unit, (k + 0.5) * unit)),
						color,
						{ name = "Snowball" }
					)
				end
			end
		end
	end
end

local function buildTree(parent: any, base: any, scale: number, rng: Builder.Rng)
	local tree = container("Model", "Tree", parent)
	local s = scale
	local trunkHeight = 9 * s
	block(tree, Vector3.new(2.4 * s, trunkHeight, 2.4 * s), CFrame.new(base + Vector3.new(0, trunkHeight / 2, 0)), Palette.Trunk, { name = "Trunk" })

	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		if rng.chance(0.8) then
			local along = Vector3.new(math.abs(dir.X), 0, math.abs(dir.Z))
			local across = Vector3.new(1, 0, 1) - along
			local size = along * 1.8 * s + across * 1.4 * s + Vector3.new(0, 1.6 * s, 0)
			block(tree, size, CFrame.new(base + dir * 2 * s + Vector3.new(0, 0.8 * s, 0)), Palette.Trunk, { name = "Root" })
		end
	end

	local yaw = rng.int(0, 3) * math.pi / 2
	local tips = {}
	for i, side in { -1, 1 } do
		local startY = trunkHeight * (if i == 1 then 0.5 else 0.65)
		local length = (if i == 1 then 4.5 else 3.5) * s
		local branch = CFrame.new(base + Vector3.new(0, startY, 0))
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(0, 0, side * math.rad(40))
		block(tree, Vector3.new(1.4 * s, length, 1.4 * s), branch * CFrame.new(0, length / 2, 0), Palette.Trunk, { name = "Branch" })
		table.insert(tips, (branch * CFrame.new(0, length, 0)).Position)
	end

	local function leaves(position: any, size: any)
		local color = if rng.chance(0.3) then Palette.SnowShade else Palette.Snow
		block(tree, size, CFrame.new(position), color, { name = "Leaves" })
	end
	leaves(base + Vector3.new(0, trunkHeight + 2 * s, 0), Vector3.new(7, 4.5, 7) * s)
	leaves(base + Vector3.new(rng.range(-1.5, 1.5) * s, trunkHeight + 5 * s, rng.range(-1.5, 1.5) * s), Vector3.new(4.5, 3, 4.5) * s)
	for _, tip in tips do
		leaves(tip + Vector3.new(0, 1.5 * s, 0), Vector3.new(4.5, 3.5, 4.5) * s)
	end
end

local function buildSnowman(parent: any, base: any, facing: any)
	local snowman = container("Model", "Snowman", parent)
	local yaw = math.atan2(-facing.X, -facing.Z)
	local origin = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local function part(size: any, offset: any, color: any, name: string)
		block(snowman, size, origin * CFrame.new(offset), color, { name = name })
	end

	part(Vector3.new(6, 5, 6), Vector3.new(0, 2.5, 0), Palette.Snow, "Body")
	part(Vector3.new(4.6, 4, 4.6), Vector3.new(0, 7, 0), Palette.Snow, "Body")
	part(Vector3.new(3.4, 3.4, 3.4), Vector3.new(0, 10.7, 0), Palette.Snow, "Head")
	part(Vector3.new(0.6, 0.6, 0.6), Vector3.new(-0.7, 11.3, -1.8), Palette.Coal, "Eye")
	part(Vector3.new(0.6, 0.6, 0.6), Vector3.new(0.7, 11.3, -1.8), Palette.Coal, "Eye")
	part(Vector3.new(0.6, 0.6, 1.8), Vector3.new(0, 10.5, -2.4), Palette.Carrot, "Nose")
	part(Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 7.8, -2.4), Palette.Coal, "Button")
	part(Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 6.4, -2.4), Palette.Coal, "Button")
	part(Vector3.new(3.8, 0.4, 3.8), Vector3.new(0, 12.6, 0), Palette.Coal, "Hat")
	part(Vector3.new(2.6, 2.2, 2.6), Vector3.new(0, 13.9, 0), Palette.Coal, "Hat")
	for _, side in { -1, 1 } do
		local arm = origin * CFrame.new(side * 3.6, 7.6, 0) * CFrame.Angles(0, 0, side * math.rad(-60))
		block(snowman, Vector3.new(0.5, 3.6, 0.5), arm, Palette.Trunk, { name = "Arm" })
	end
end

local function buildDecorations(parent: any, cells: { [number]: { [number]: Cell } })
	local rng = Builder.rng(SEED + 3)
	local occupied: { { x: number, z: number, r: number } } = {}

	local function isFree(x: number, z: number, radius: number): boolean
		local cell = cells[x] and cells[x][z]
		if not cell or cell.kind ~= "snow" then
			return false
		end
		local margin = math.ceil(radius)
		for dx = -margin, margin do
			for dz = -margin, margin do
				local xx, zz = x + dx, z + dz
				if isPlaza(xx, zz) or isCorridor(xx, zz) or isStatueArea(xx, zz) then
					return false
				end
			end
		end
		for _, other in occupied do
			if math.sqrt((other.x - x) ^ 2 + (other.z - z) ^ 2) < other.r + radius then
				return false
			end
		end
		return true
	end

	local function place(count: number, radius: number, build: (x: number, z: number, ground: number) -> ())
		local placed, attempts = 0, 0
		while placed < count and attempts < 2000 do
			attempts += 1
			local x, z = rng.int(GRID_MIN, GRID_MAX), rng.int(GRID_MIN, GRID_MAX)
			if isFree(x, z, radius) then
				table.insert(occupied, { x = x, z = z, r = radius })
				build(x, z, cells[x][z].h * VOXEL)
				placed += 1
			end
		end
	end

	-- Hand-placed snowmen west of the plaza, looking at the spawn.
	for _, z in { -12, 12 } do
		local base = Vector3.new(-30, 0, z)
		buildSnowman(parent, base, (Vector3.new(0, 0, 0) - base).Unit)
		table.insert(occupied, { x = -8, z = z // VOXEL, r = 2 })
	end

	local trees = container("Folder", "Trees", parent)
	place(16, 2.5, function(x, z, ground)
		buildTree(trees, cellCenter(x, z, ground), rng.range(1.1, 1.6), rng)
	end)

	local props = container("Folder", "Props", parent)
	place(12, 1, function(x, z, ground)
		local base = cellCenter(x, z, ground)
		for _ = 1, rng.int(2, 4) do
			local width = rng.int(2, 4)
			local height = width * rng.range(0.6, 1)
			local offset = Vector3.new(rng.range(-1.5, 1.5), height / 2, rng.range(-1.5, 1.5))
			block(props, Vector3.new(width, height, width), CFrame.new(base + offset), if rng.chance(0.3) then Palette.SnowShade else Palette.Snow, {
				name = "SnowPile",
			})
		end
	end)

	place(7, 1, function(x, z, ground)
		local base = cellCenter(x, z, ground)
		for _ = 1, rng.int(1, 3) do
			local width = rng.range(2, 3.5)
			local height = rng.range(1.5, 3)
			local offset = Vector3.new(rng.range(-1.2, 1.2), 0, rng.range(-1.2, 1.2))
			block(props, Vector3.new(width, height, width), CFrame.new(base + offset + Vector3.new(0, height / 2, 0)), Palette.Rock, { name = "Rock" })
			block(props, Vector3.new(width + 0.3, 0.5, width + 0.3), CFrame.new(base + offset + Vector3.new(0, height + 0.25, 0)), Palette.Snow, {
				name = "RockSnow",
			})
		end
	end)

	place(6, 1, function(x, z, ground)
		local base = cellCenter(x, z, ground)
		for _ = 1, rng.int(2, 3) do
			local height = rng.range(3, 6.5)
			local tilt = CFrame.Angles(math.rad(rng.range(-15, 15)), rng.range(0, math.pi), math.rad(rng.range(-15, 15)))
			local offset = Vector3.new(rng.range(-1.2, 1.2), height / 2 - 0.5, rng.range(-1.2, 1.2))
			block(props, Vector3.new(1.6, height, 1.6), CFrame.new(base + offset) * tilt, if rng.chance(0.5) then Palette.Ice else Palette.IceDark, {
				name = "IceCrystal",
				transparency = 0.15,
				reflectance = 0.15,
			})
		end
	end)
end

local Spawn = {}

function Spawn.build(): any
	local model = container("Model", "Spawn")
	local cells = buildHeightmap()

	buildGround(container("Folder", "Ground", model), cells)
	buildTiles(container("Folder", "Plaza", model))
	buildSpawnLocation(model)

	local lamps = container("Folder", "Lamps", model)
	for _, position in { Vector3.new(-18, TILE_HEIGHT, -18), Vector3.new(18, TILE_HEIGHT, -18), Vector3.new(-18, TILE_HEIGHT, 18), Vector3.new(18, TILE_HEIGHT, 18) } do
		buildLamp(lamps, position)
	end
	for _, x in { -10, 10 } do
		buildLamp(lamps, Vector3.new(x, 0, -66))
	end

	buildBridgeAndGate(model)
	buildSnowballStatue(model)
	buildDecorations(container("Folder", "Decorations", model), cells)

	return model
end

return Spawn
