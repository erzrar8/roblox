--!strict
-- Spawn island: tiled plaza with invisible spawn points around a frozen fountain, a winding path to the
-- fenced snow field where players roll their snowballs, and a canyon from the field to the (not yet
-- built) Zone 1 gate. A ring of tall mountains encloses everything.
--
-- Grid: 1 voxel = 4 studs, cell (x, z) covers X in [4x, 4x+4] and Z in [4z, 4z+4]. Ground top of
-- height level h is at Y = 4h. Players spawn facing -Z: fountain, then path, field and gate.

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
-- Elongated rounded-rectangle island (radii in cells), centred slightly towards -Z.
local ISLAND_RX, ISLAND_RZ, ISLAND_CZ = 34.5, 48.5, -6
-- Ring of snowy terraced mountains around the island, so a zoomed-out camera never sees the void.
local MOUNTAIN_BAND = 12
local GRID_MIN_X, GRID_MAX_X = -48, 47
local GRID_MIN_Z, GRID_MAX_Z = -68, 56
local ISLAND_BOTTOM = -12
local CAP = 1.5
-- Snow plain below the mountain tops, filling the view past the mountains out to the haze.
local PLAIN_TOP = 16
local BOUNDARY_HEIGHT = 120
local TILE_HEIGHT = 0.4
local SEED = 2026

type Area = { x0: number, x1: number, z0: number, z1: number }
type Cell = { h: number, kind: string }
type Cells = { [number]: { [number]: Cell } }

-- Layout, in grid cells.
local PLAZA: Area = { x0 = -10, x1 = 9, z0 = 12, z1 = 33 }
local FIELD: Area = { x0 = -24, x1 = 23, z0 = -46, z1 = -8 }
local STATUE_AREA: Area = { x0 = 13, x1 = 18, z0 = 20, z1 = 25 }
local PATH_Z0, PATH_Z1 = FIELD.z1 + 1, PLAZA.z0 - 1
local CANYON_START, CANYON_END = -54, -62

-- Layout, in studs.
local FOUNTAIN_CENTER = Vector3.new(0, TILE_HEIGHT, 92)
local SPAWN_COUNT, SPAWN_RADIUS = 8, 24
local STATUE_CENTER = Vector3.new(64, 13, 92)
local SHOP_CENTER = Vector3.new(0, TILE_HEIGHT, 127)

local function inArea(area: Area, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= area.x0 - m and x <= area.x1 + m and z >= area.z0 - m and z <= area.z1 + m
end

-- Path centre column per row: a single smooth bend towards -X, at most one cell shift per row.
local function pathCenter(z: number): number
	local t = (PATH_Z1 - z) / (PATH_Z1 - PATH_Z0)
	return -math.floor(4 * math.sin(t * math.pi) ^ 2 + 0.5)
end

local function isNearPath(x: number, z: number, margin: number): boolean
	if z < PATH_Z0 or z > PATH_Z1 then
		return false
	end
	local c = pathCenter(z)
	return x >= c - 2 - margin and x <= c + 1 + margin
end

-- Paved strip from the field's north opening through the canyon to the gate.
local function isNorthPath(x: number, z: number): boolean
	return x >= -2 and x <= 1 and z < FIELD.z0 and z >= CANYON_END
end

-- Corridor through the rim towards the gate, kept flat and free of decorations.
local function isCorridor(x: number, z: number): boolean
	return x >= -3 and x <= 2 and z < FIELD.z0
end

-- Flat pass cut through the mountains up to the Zone 1 gate; mountains close it off behind the gate.
local function isCanyon(x: number, z: number): boolean
	return x >= -4 and x <= 3 and z < FIELD.z0 and z >= CANYON_END
end

-- Normalised superellipse grown by `grow` cells: <= 1 is inside.
local function islandDistance(x: number, z: number, grow: number?): number
	local g = grow or 0
	local nx = (x + 0.5) / (ISLAND_RX + g)
	local nz = (z + 0.5 - ISLAND_CZ) / (ISLAND_RZ + g)
	return (nx ^ 4 + nz ^ 4) ^ 0.25
end

-- How many cells outside the island edge this cell lies, or nil when beyond the mountain ring.
local function mountainDepth(x: number, z: number): number?
	for depth = 1, MOUNTAIN_BAND do
		if islandDistance(x, z, depth) <= 1 then
			return depth
		end
	end
	return nil
end

local function cellCenter(x: number, z: number, y: number): any
	return Vector3.new(x * VOXEL + VOXEL / 2, y, z * VOXEL + VOXEL / 2)
end

local function buildHeightmap(): Cells
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

	-- Separate 3x3 noise for the mountains, so the island terrain stays as it was.
	local peakRng = Builder.rng(SEED + 5)
	local peakNoise: { [string]: number } = {}
	local function peak(x: number, z: number): number
		local key = `{x // 3},{z // 3}`
		local value = peakNoise[key]
		if value == nil then
			value = peakRng.next()
			peakNoise[key] = value
		end
		return value
	end

	local cells: Cells = {}
	for x = GRID_MIN_X, GRID_MAX_X do
		cells[x] = {}
		for z = GRID_MIN_Z, GRID_MAX_Z do
			local d = islandDistance(x, z)
			local depth = if d > 1 then mountainDepth(x, z) else nil
			if depth and isCanyon(x, z) then
				cells[x][z] = { h = 0, kind = if isNorthPath(x, z) then "stone" else "snow" }
			elseif depth then
				-- Same terraces as the island rim, rising outwards from 2-3 levels to about 12.
				local h = 2 + depth * 0.6 + peak(x, z) * 3.5
				cells[x][z] = { h = math.floor(h), kind = "mountain" }
			elseif d > 1 then
				cells[x][z] = { h = PLAIN_TOP // VOXEL, kind = "plain" }
			elseif d <= 1 then
				local n = noise(x, z)
				local h
				if d > 0.86 then
					h = if n < 0.4 then 3 else 2
				elseif d > 0.74 then
					h = if n < 0.3 then 2 else 1
				else
					h = if d > 0.5 and n > 0.85 then 1 else 0
				end

				if isCorridor(x, z) or isCanyon(x, z) or inArea(STATUE_AREA, x, z) or inArea(FIELD, x, z, 1) or isNearPath(x, z, 1) then
					h = 0
				end

				local kind = "snow"
				if inArea(PLAZA, x, z) or isNearPath(x, z, 0) or isNorthPath(x, z) then
					kind = "stone"
				elseif inArea(FIELD, x, z) then
					kind = "field"
				end
				cells[x][z] = { h = if kind == "snow" then h else 0, kind = kind }
			end
		end
	end
	return cells
end

local function groundAt(cells: Cells, position: any): number
	local column = cells[position.X // VOXEL]
	local cell = column and column[position.Z // VOXEL]
	return if cell then cell.h * VOXEL else 0
end

local GROUND_TOP = {
	snow = { color = Palette.Snow, name = "Snow" },
	field = { color = Palette.FieldSnow, name = "FieldSnow" },
	stone = { color = Palette.Grout, name = "Grout" },
	mountain = { color = Palette.Snow, name = "MountainSnow" },
	plain = { color = Palette.Snow, name = "PlainSnow" },
}

local function buildGround(parent: any, cells: Cells)
	local function keyAt(x: number, z: number): string?
		local column = cells[x]
		local cell = column and column[z]
		return cell and `{cell.kind}:{cell.h}`
	end

	for _, rect in Builder.greedyRects(GRID_MIN_X, GRID_MAX_X, GRID_MIN_Z, GRID_MAX_Z, keyAt) do
		local cell = cells[rect.x0][rect.z0]
		local top = cell.h * VOXEL
		local x0, x1 = rect.x0 * VOXEL, (rect.x1 + 1) * VOXEL
		local z0, z1 = rect.z0 * VOXEL, (rect.z1 + 1) * VOXEL
		local surface = GROUND_TOP[cell.kind]
		box(parent, Vector3.new(x0, ISLAND_BOTTOM, z0), Vector3.new(x1, top - CAP, z1), Palette.Dirt, { name = "Dirt" })
		box(parent, Vector3.new(x0, top - CAP, z0), Vector3.new(x1, top, z1), surface.color, { name = surface.name })
	end

	-- Extend the plain from the grid edges outwards; it must never cover the grid itself.
	local gx0, gx1 = GRID_MIN_X * VOXEL, (GRID_MAX_X + 1) * VOXEL
	local gz0, gz1 = GRID_MIN_Z * VOXEL, (GRID_MAX_Z + 1) * VOXEL
	local far = 1024
	local bottom, top = PLAIN_TOP - 8, PLAIN_TOP
	for _, rect in {
		{ Vector3.new(-far, bottom, -far), Vector3.new(far, top, gz0) },
		{ Vector3.new(-far, bottom, gz1), Vector3.new(far, top, far) },
		{ Vector3.new(-far, bottom, gz0), Vector3.new(gx0, top, gz1) },
		{ Vector3.new(gx1, bottom, gz0), Vector3.new(far, top, gz1) },
	} do
		local plain = box(parent, rect[1], rect[2], Palette.Snow, { name = "SnowPlain", studs = false })
		plain.CastShadow = false
	end
end

-- The mountains are climbable terraces, so invisible walls stand on every mountain cell bordering the
-- playable area (island and canyon). Transparent parts do not block the default camera.
local function buildBoundary(parent: any, cells: Cells)
	local function isMountain(x: number, z: number): boolean
		local cell = cells[x] and cells[x][z]
		return cell ~= nil and (cell.kind == "mountain" or cell.kind == "plain")
	end
	local function keyAt(x: number, z: number): string?
		if not isMountain(x, z) then
			return nil
		end
		for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = x + offset[1], z + offset[2]
			if cells[nx] and cells[nx][nz] and not isMountain(nx, nz) then
				return "wall"
			end
		end
		return nil
	end

	for _, rect in Builder.greedyRects(GRID_MIN_X, GRID_MAX_X, GRID_MIN_Z, GRID_MAX_Z, keyAt) do
		local wall = box(
			parent,
			Vector3.new(rect.x0 * VOXEL, 0, rect.z0 * VOXEL),
			Vector3.new((rect.x1 + 1) * VOXEL, BOUNDARY_HEIGHT, (rect.z1 + 1) * VOXEL),
			Palette.Snow,
			{ name = "Boundary", transparency = 1, studs = false }
		)
		wall.CastShadow = false
		wall.CanQuery = false
	end
end

local function buildTiles(parent: any)
	local rng = Builder.rng(SEED + 1)
	local function tile(x: number, z: number, color: any)
		block(parent, Vector3.new(3.6, TILE_HEIGHT, 3.6), CFrame.new(cellCenter(x, z, TILE_HEIGHT / 2)), color, { name = "Tile" })
	end
	local function paving(): any
		return if rng.chance(0.25) then Palette.TileAlt else Palette.Tile
	end

	for x = PLAZA.x0, PLAZA.x1 do
		for z = PLAZA.z0, PLAZA.z1 do
			local onEdge = x == PLAZA.x0 or x == PLAZA.x1 or z == PLAZA.z0 or z == PLAZA.z1
			local pathOpening = z == PLAZA.z0 and x >= -2 and x <= 1
			local center = cellCenter(x, z, 0)
			local fountainDistance = math.sqrt((center.X - FOUNTAIN_CENTER.X) ^ 2 + (center.Z - FOUNTAIN_CENTER.Z) ^ 2)
			local onRing = fountainDistance > 15 and fountainDistance < 19
			tile(x, z, if (onEdge and not pathOpening) or onRing then Palette.TileDark else paving())
		end
	end

	for z = PATH_Z1, PATH_Z0, -1 do
		local c = pathCenter(z)
		for x = c - 2, c + 1 do
			tile(x, z, if x == c - 2 or x == c + 1 then Palette.TileDark else paving())
		end
	end

	for z = FIELD.z0 - 1, CANYON_END, -1 do
		for x = -2, 1 do
			tile(x, z, if x == -2 or x == 1 then Palette.TileDark else paving())
		end
	end
end

-- Invisible spawn points in a ring around the fountain; Roblox picks one at random per spawn.
local function buildSpawnPoints(parent: any)
	local folder = container("Folder", "SpawnPoints", parent)
	for i = 0, SPAWN_COUNT - 1 do
		local angle = i * 2 * math.pi / SPAWN_COUNT
		local position = FOUNTAIN_CENTER + Vector3.new(math.sin(angle) * SPAWN_RADIUS, 0.5, math.cos(angle) * SPAWN_RADIUS)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `SpawnPoint{i + 1}`
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		-- Identity rotation: players spawn looking down -Z, towards the path and the snow field.
		spawn.CFrame = CFrame.new(position)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CastShadow = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.AllowTeamChangeOnTouch = false
		spawn.Parent = folder
	end
end

-- Voxel disc (or ring when rInner > 0) centred on `center`, merged into one part per row/segment.
local function ring(parent: any, center: any, unit: number, rOuter: number, rInner: number, y0: number, y1: number, color: any, options: Builder.BlockOptions)
	local function halfWidth(r: number, v: number): number
		if r <= math.abs(v) then
			return 0
		end
		return math.floor(math.sqrt(r * r - v * v) / unit + 0.5) * unit
	end

	local rows = math.ceil(rOuter / unit)
	for j = -rows, rows - 1 do
		local v = (j + 0.5) * unit
		local outer = halfWidth(rOuter, v)
		if outer > 0 then
			local inner = halfWidth(rInner, v)
			local segments = if inner > 0 then { { -outer, -inner }, { inner, outer } } else { { -outer, outer } }
			for _, segment in segments do
				if segment[2] > segment[1] then
					box(
						parent,
						center + Vector3.new(segment[1], y0, v - unit / 2),
						center + Vector3.new(segment[2], y1, v + unit / 2),
						color,
						options
					)
				end
			end
		end
	end
end

local function buildFrozenFountain(parent: any)
	local fountain = container("Model", "FrozenFountain", parent)
	local rng = Builder.rng(SEED + 4)
	local c = FOUNTAIN_CENTER
	local ice = { name = "Ice", material = Enum.Material.Ice, reflectance = 0.2, transparency = 0.1, studs = false }

	-- Basin: plinth, floor, wall with a snowy rim, frozen water.
	ring(fountain, c, 2, 12, 0, 0, 0.8, Palette.Grout, { name = "Plinth" })
	ring(fountain, c, 2, 10, 0, 0.8, 1.6, Palette.TileDark, { name = "BasinFloor" })
	ring(fountain, c, 2, 10, 8, 1.6, 3.8, Palette.TileDark, { name = "BasinWall" })
	ring(fountain, c, 2, 10, 8, 3.8, 4.4, Palette.Snow, { name = "RimSnow" })
	ring(fountain, c, 2, 8, 0, 1.6, 3, Palette.Ice, ice)

	-- Middle tier.
	block(fountain, Vector3.new(3, 6, 3), CFrame.new(c + Vector3.new(0, 6, 0)), Palette.TileDark, { name = "Column" })
	ring(fountain, c, 1, 4.6, 0, 9, 9.8, Palette.Grout, { name = "Bowl" })
	ring(fountain, c, 1, 4.6, 3.4, 9.8, 10.8, Palette.TileDark, { name = "BowlWall" })
	ring(fountain, c, 1, 4.6, 3.4, 10.8, 11.2, Palette.Snow, { name = "RimSnow" })
	ring(fountain, c, 1, 3.4, 0, 9.8, 10.5, Palette.Ice, ice)

	-- Top tier.
	block(fountain, Vector3.new(1.6, 3, 1.6), CFrame.new(c + Vector3.new(0, 12, 0)), Palette.TileDark, { name = "Column" })
	ring(fountain, c, 1, 2.4, 0, 13.5, 14.2, Palette.Grout, { name = "Bowl" })
	ring(fountain, c, 1, 1.6, 0, 14.2, 14.6, Palette.Ice, ice)

	-- The water jet, frozen mid-air, glowing faintly.
	local jet = block(fountain, Vector3.new(1.2, 5, 1.2), CFrame.new(c + Vector3.new(0, 17, 0)), Palette.Ice, ice)
	local glow = Instance.new("PointLight")
	glow.Color = Palette.IceDark
	glow.Range = 16
	glow.Brightness = 0.8
	glow.Parent = jet

	-- Frozen spray arcing out of the top bowl, frozen falls from the middle bowl and icicles under it.
	for i = 0, 5 do
		local angle = i * math.pi / 3 + math.pi / 6
		local spray = CFrame.new(c + Vector3.new(0, 16.5, 0))
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -1.4)
			* CFrame.Angles(math.rad(-35), 0, 0)
		block(fountain, Vector3.new(0.8, 3.4, 0.8), spray, if i % 2 == 0 then Palette.Ice else Palette.IceDark, ice)
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local fall = CFrame.new(c + Vector3.new(0, 9.4, 0))
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, -1.6, -4.4)
			* CFrame.Angles(math.rad(12), 0, 0)
		block(fountain, Vector3.new(1.4, 4.2, 0.6), fall, Palette.Ice, ice)
	end
	for i = 0, 11 do
		local angle = i * math.pi / 6 + math.pi / 12
		local length = rng.range(1, 2.2)
		local position = c + Vector3.new(math.sin(angle) * 4, 9 - length / 2, math.cos(angle) * 4)
		block(fountain, Vector3.new(0.4, length, 0.4), CFrame.new(position), Palette.IceDark, ice)
	end
	-- Ice chunks poking out of the frozen basin.
	for _ = 1, 6 do
		local angle = rng.range(0, math.pi * 2)
		local radius = rng.range(4.5, 7)
		local height = rng.range(1.2, 2.6)
		local position = c + Vector3.new(math.sin(angle) * radius, 3 + height / 2 - 0.3, math.cos(angle) * radius)
		block(fountain, Vector3.new(1.4, height, 1.4), CFrame.new(position) * CFrame.Angles(0, angle, math.rad(rng.range(-20, 20))), Palette.IceDark, ice)
	end
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

local function buildBench(parent: any, base: any, facing: any)
	local bench = container("Model", "Bench", parent)
	local origin = CFrame.new(base) * CFrame.Angles(0, math.atan2(-facing.X, -facing.Z), 0)
	local function part(size: any, offset: any, color: any, name: string)
		block(bench, size, origin * CFrame.new(offset), color, { name = name })
	end
	for _, x in { -2.4, 2.4 } do
		part(Vector3.new(0.8, 1.6, 2), Vector3.new(x, 0.8, 0), Palette.LampPost, "Leg")
	end
	part(Vector3.new(7, 0.6, 2.4), Vector3.new(0, 1.9, 0), Palette.Wood, "Seat")
	part(Vector3.new(7, 2, 0.6), Vector3.new(0, 3.2, 1.2), Palette.Wood, "Back")
	part(Vector3.new(7.2, 0.4, 0.9), Vector3.new(0, 4.4, 1.2), Palette.Snow, "Snow")
end

local function buildSign(parent: any, size: any, cframe: any, text: string)
	local sign = block(parent, size, cframe, Palette.Sign, { name = "Sign" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces +Z, towards the spawn
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 30, 60)
	label.Parent = gui
end

-- 24-stud wide arch over a 16-stud opening at `z`, with a sign facing +Z.
local function buildArch(parent: any, name: string, z: number, baseY: number, colors: { any }, reflectance: number, text: string): any
	local arch = container("Model", name, parent)
	for _, x in { -10, 10 } do
		for level = 0, 3 do
			block(arch, Vector3.new(4, 4, 4), CFrame.new(x, baseY + level * 4 + 2, z), colors[level % 2 + 1], {
				name = "Pillar",
				reflectance = reflectance,
			})
		end
	end
	for i = 0, 5 do
		block(arch, Vector3.new(4, 4, 4), CFrame.new(-10 + i * 4, baseY + 18, z), colors[(i + 1) % 2 + 1], {
			name = "Lintel",
			reflectance = reflectance,
		})
	end
	box(arch, Vector3.new(-12.5, baseY + 20, z - 2.5), Vector3.new(12.5, baseY + 21.5, z + 2.5), Palette.Snow, { name = "Cap" })
	buildSign(arch, Vector3.new(14, 4.5, 0.5), CFrame.new(0, baseY + 13.25, z + 2.25), text)
	return arch
end

-- Zone 1 gate at the far end of the canyon; the mountains behind it stay closed until Zone 1 is built.
local function buildGate(parent: any)
	local gateZ = CANYON_END * VOXEL + VOXEL / 2
	local gate = buildArch(parent, "Zone1Gate", gateZ, 0, { Palette.Ice, Palette.IceDark }, 0.1, "ZONE 1\nCOMING SOON")
	-- Invisible wall across the whole canyon until Zone 1 exists; later this becomes the zone unlock barrier.
	block(gate, Vector3.new(32, 24, 1), CFrame.new(0, 12, gateZ), Palette.Ice, {
		name = "ZoneBarrier",
		transparency = 1,
		studs = false,
	})
end

local function buildSnowField(parent: any)
	local x0, x1 = FIELD.x0 * VOXEL, (FIELD.x1 + 1) * VOXEL
	local z0, z1 = FIELD.z0 * VOXEL, (FIELD.z1 + 1) * VOXEL

	local fence = container("Model", "FieldFence", parent)
	local function fenceRun(a: any, b: any)
		local delta = b - a
		local length = math.abs(delta.X) + math.abs(delta.Z)
		local posts = math.max(1, math.floor(length / 8 + 0.5))
		for i = 0, posts do
			local p = a + delta * (i / posts)
			block(fence, Vector3.new(1.2, 4, 1.2), CFrame.new(p + Vector3.new(0, 2, 0)), Palette.Wood, { name = "Post" })
			block(fence, Vector3.new(1.6, 0.5, 1.6), CFrame.new(p + Vector3.new(0, 4.25, 0)), Palette.Snow, { name = "PostSnow" })
		end
		local size = Vector3.new(math.abs(delta.X) + 0.5, 0.5, math.abs(delta.Z) + 0.5)
		for _, y in { 1.4, 2.9 } do
			block(fence, size, CFrame.new((a + b) / 2 + Vector3.new(0, y, 0)), Palette.Wood, { name = "Rail" })
		end
	end
	-- Both short sides open onto the paths: south towards the spawn plaza, north towards the canyon and the Zone 1 gate.
	fenceRun(Vector3.new(x0, 0, z1), Vector3.new(-8, 0, z1))
	fenceRun(Vector3.new(8, 0, z1), Vector3.new(x1, 0, z1))
	fenceRun(Vector3.new(x0, 0, z0), Vector3.new(-8, 0, z0))
	fenceRun(Vector3.new(8, 0, z0), Vector3.new(x1, 0, z0))
	fenceRun(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1))
	fenceRun(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1))
end

-- Invisible volumes read by the client (ZoneBanner) to show which zone the player is in.
-- Persistent so they replicate even when StreamingEnabled is on and the player is far away.
local function buildZones(parent: any)
	local zones = container("Model", "Zones", parent)
	zones.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local function zone(name: string, title: string, subtitle: string, area: Area, height: number)
		local part = box(
			zones,
			Vector3.new(area.x0 * VOXEL, 0, area.z0 * VOXEL),
			Vector3.new((area.x1 + 1) * VOXEL, height, (area.z1 + 1) * VOXEL),
			Palette.FieldSnow,
			{ name = name, transparency = 1, canCollide = false, studs = false }
		)
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part:SetAttribute("ZoneName", title)
		part:SetAttribute("ZoneSubtitle", subtitle)
	end

	zone("Spawn", "SPAWN", "Safe zone", PLAZA, 40)
	zone("SnowField", "SNOW FIELD", "Roll your snowball!", FIELD, 40)
end

-- Voxel sphere made of 2-stud cubes, merged into one part per row.
local function buildSnowballStatue(parent: any)
	local statue = container("Model", "SnowballStatue", parent)
	local rng = Builder.rng(SEED + 2)
	local center = STATUE_CENTER
	local base = Vector3.new(center.X, 0, center.Z)
	box(statue, base - Vector3.new(8, 0, 8), base + Vector3.new(8, 1, 8), Palette.Grout, { name = "Pedestal" })
	box(statue, base - Vector3.new(7, -1, 7), base + Vector3.new(7, 2, 7), Palette.TileDark, { name = "Pedestal" })

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

local function buildDecorations(parent: any, cells: Cells)
	local rng = Builder.rng(SEED + 3)
	local occupied: { { x: number, z: number, r: number } } = {}

	local function isReserved(x: number, z: number): boolean
		return inArea(PLAZA, x, z)
			or inArea(FIELD, x, z, 1)
			or inArea(STATUE_AREA, x, z)
			or isNearPath(x, z, 1)
			or isCorridor(x, z)
	end

	local function isFree(x: number, z: number, radius: number, kind: string): boolean
		local cell = cells[x] and cells[x][z]
		if not cell or cell.kind ~= kind then
			return false
		end
		local margin = math.ceil(radius)
		for dx = -margin, margin do
			for dz = -margin, margin do
				if isReserved(x + dx, z + dz) then
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

	local function place(count: number, radius: number, build: (x: number, z: number, ground: number) -> (), kind: string?)
		local placed, attempts = 0, 0
		while placed < count and attempts < 6000 do
			attempts += 1
			local x, z = rng.int(GRID_MIN_X, GRID_MAX_X), rng.int(GRID_MIN_Z, GRID_MAX_Z)
			if isFree(x, z, radius, kind or "snow") then
				table.insert(occupied, { x = x, z = z, r = radius })
				build(x, z, cells[x][z].h * VOXEL)
				placed += 1
			end
		end
	end

	-- Hand-placed snowmen: two watching the fountain, two flanking the field entrance.
	local plazaWest = PLAZA.x0 * VOXEL - 12
	local snowmen = {
		{ position = Vector3.new(plazaWest, 0, FOUNTAIN_CENTER.Z - 16), lookAt = FOUNTAIN_CENTER },
		{ position = Vector3.new(plazaWest, 0, FOUNTAIN_CENTER.Z + 16), lookAt = FOUNTAIN_CENTER },
		{ position = Vector3.new(-22, 0, -18), lookAt = Vector3.new(0, 0, 0) },
		{ position = Vector3.new(22, 0, -18), lookAt = Vector3.new(0, 0, 0) },
	}
	for _, snowman in snowmen do
		local base = Vector3.new(snowman.position.X, groundAt(cells, snowman.position), snowman.position.Z)
		local facing = Vector3.new(snowman.lookAt.X - base.X, 0, snowman.lookAt.Z - base.Z).Unit
		buildSnowman(parent, base, facing)
		table.insert(occupied, { x = base.X // VOXEL, z = base.Z // VOXEL, r = 2 })
	end

	local trees = container("Folder", "Trees", parent)
	place(48, 2.5, function(x, z, ground)
		buildTree(trees, cellCenter(x, z, ground), rng.range(1.1, 1.6), rng)
	end)
	place(40, 2.5, function(x, z, ground)
		buildTree(trees, cellCenter(x, z, ground), rng.range(1.2, 1.8), rng)
	end, "mountain")

	local props = container("Folder", "Props", parent)
	place(30, 1, function(x, z, ground)
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

	place(16, 1, function(x, z, ground)
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

	place(14, 1, function(x, z, ground)
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

-- Market stall at the south end of the plaza, facing the fountain (-Z), with Santa leaning on it.
local function buildShop(parent: any)
	local shop = container("Model", "Shop", parent)
	local rng = Builder.rng(SEED + 6)
	local origin = CFrame.new(SHOP_CENTER)
	local function at(x: number, y: number, z: number): any
		return origin * CFrame.new(x, y, z)
	end
	local function part(name: string, size: any, cframe: any, color: any, studs: boolean?): any
		return block(shop, size, cframe, color, { name = name, studs = studs })
	end

	-- Counter: planked front, dark top board.
	local counterTop = 3.3
	part("Counter", Vector3.new(20, 2.8, 4.5), at(0, 1.4, 0.25), Palette.Wood)
	for i, y in { 0.47, 1.4, 2.33 } do
		part("Plank", Vector3.new(20.2, 0.85, 0.2), at(0, y, -2.05), if i % 2 == 0 then Palette.WoodLight else Palette.Wood)
	end
	for _, x in { -9.9, 0, 9.9 } do
		part("Trim", Vector3.new(0.6, 2.8, 0.3), at(x, 1.4, -2.15), Palette.WoodDark)
	end
	part("CounterTop", Vector3.new(21.2, 0.5, 5.4), at(0, counterTop - 0.25, 0.2), Palette.WoodDark)

	-- Posts: the back pair is taller so the awning slopes down towards the front.
	local roofFront, roofBack = Vector3.new(0, 9.6, -4.6), Vector3.new(0, 11.8, 3.4)
	for _, x in { -10.2, 10.2 } do
		part("Post", Vector3.new(0.9, 9.4, 0.9), at(x, 4.7, -2.1), Palette.WoodLight)
		part("Post", Vector3.new(0.9, 11.4, 0.9), at(x, 5.7, 2.6), Palette.WoodLight)
	end
	part("Beam", Vector3.new(21.4, 0.7, 0.7), at(0, 9.3, -2.1), Palette.WoodDark)
	part("Beam", Vector3.new(21.4, 0.7, 0.7), at(0, 11.3, 2.6), Palette.WoodDark)

	-- Awning: red and white stripes, sloped, with a stepped "scalloped" edge at the front.
	local slope = roofBack - roofFront
	local length = slope.Magnitude
	local roof = origin * CFrame.new((roofFront + roofBack) / 2) * CFrame.Angles(-math.atan2(slope.Y, slope.Z), 0, 0)
	local stripes, stripeWidth = 12, 2
	for i = 0, stripes - 1 do
		local x = -stripes * stripeWidth / 2 + stripeWidth * (i + 0.5)
		local color = if i % 2 == 0 then Palette.AwningRed else Palette.AwningWhite
		part("Awning", Vector3.new(stripeWidth, 0.6, length + 1), roof * CFrame.new(x, 0, 0), color)
		local edge = roof * CFrame.new(x, 0, -(length + 1) / 2)
		part("Flap", Vector3.new(stripeWidth, 0.9, 0.3), edge * CFrame.new(0, -0.7, 0.15), color)
		part("Flap", Vector3.new(stripeWidth * 0.5, 0.7, 0.3), edge * CFrame.new(0, -1.45, 0.15), color)
	end
	-- Snow on the awning: one slab per stripe with a ragged front edge, plus a few lumps.
	for i = 0, stripes - 1 do
		local x = -stripes * stripeWidth / 2 + stripeWidth * (i + 0.5)
		local depth = (length + 1) * rng.range(0.62, 0.9)
		local z = (length + 1) / 2 - depth / 2
		part("RoofSnow", Vector3.new(stripeWidth + 0.1, 0.7, depth), roof * CFrame.new(x, 0.62, z), Palette.Snow)
	end
	for _ = 1, 6 do
		local size = Vector3.new(rng.range(2, 4), rng.range(0.5, 0.9), rng.range(2, 3))
		part("RoofSnow", size, roof * CFrame.new(rng.range(-9, 9), 0.9 + size.Y / 2, rng.range(0, 3)), Palette.Snow)
	end
	for _ = 1, 7 do
		local height = rng.range(0.6, 1.4)
		local edge = roof * CFrame.new(rng.range(-11, 11), 0, -(length + 1) / 2)
		block(shop, Vector3.new(0.3, height, 0.3), edge * CFrame.new(0, -1.8 - height / 2, 0.15), Palette.Ice, {
			name = "Icicle",
			transparency = 0.15,
			studs = false,
		})
	end

	-- Sign on top of the awning.
	local sign = part("Sign", Vector3.new(9, 2.6, 0.5), at(0, 13.9, 3.2), Palette.AwningRed)
	part("SignFrame", Vector3.new(9.6, 0.4, 0.7), at(0, 12.45, 3.2), Palette.WoodDark)
	part("SignSnow", Vector3.new(9.6, 0.5, 0.9), at(0, 15.45, 3.2), Palette.Snow)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- faces -Z, towards the fountain
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = "SHOP"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(90, 10, 14)
	label.Parent = gui

	-- Open crate (bottom and four walls) with snowballs poking out of the top.
	local function crate(cframe: any, size: any, snowballs: boolean)
		local wall = 0.3
		local half = size / 2
		part("Crate", Vector3.new(size.X, wall, size.Z), cframe * CFrame.new(0, -half.Y + wall / 2, 0), Palette.WoodLight)
		for _, side in { -1, 1 } do
			part("Crate", Vector3.new(size.X, size.Y, wall), cframe * CFrame.new(0, 0, side * (half.Z - wall / 2)), Palette.WoodLight)
			part("Crate", Vector3.new(wall, size.Y, size.Z - 2 * wall), cframe * CFrame.new(side * (half.X - wall / 2), 0, 0), Palette.WoodLight)
			part("Slat", Vector3.new(size.X + 0.05, 0.3, wall + 0.05), cframe * CFrame.new(0, half.Y * 0.35, side * (half.Z - wall / 2)), Palette.Wood)
		end
		if snowballs then
			local columns, rows = math.max(1, math.floor(size.X / 1.1)), math.max(1, math.floor(size.Z / 1.1))
			for cx = 0, columns - 1 do
				for cz = 0, rows - 1 do
					local diameter = rng.range(0.9, 1.15)
					local x = -half.X + wall + (cx + 0.5) * (size.X - 2 * wall) / columns
					local z = -half.Z + wall + (cz + 0.5) * (size.Z - 2 * wall) / rows
					local ball = part("Snowball", Vector3.new(diameter, diameter, diameter), cframe * CFrame.new(x, half.Y - 0.25, z), Palette.Snow, false)
					ball.Shape = Enum.PartType.Ball
				end
			end
		end
	end

	local function gift(cframe: any, size: any, color: any, ribbon: any)
		part("Gift", size, cframe, color, false)
		part("Ribbon", Vector3.new(size.X + 0.06, size.Y + 0.06, 0.3), cframe, ribbon, false)
		part("Ribbon", Vector3.new(0.3, size.Y + 0.06, size.Z + 0.06), cframe, ribbon, false)
		for _, side in { -1, 1 } do
			part("Bow", Vector3.new(0.5, 0.4, 0.5), cframe * CFrame.new(side * 0.3, size.Y / 2 + 0.2, 0) * CFrame.Angles(0, 0, side * 0.5), ribbon, false)
		end
	end

	-- On the counter.
	crate(at(-6, counterTop + 0.8, 0), Vector3.new(4.2, 1.6, 3), true)
	crate(at(-1.2, counterTop + 0.8, 0.2), Vector3.new(4.2, 1.6, 3), true)
	gift(at(4.2, counterTop + 0.9, 0.4), Vector3.new(1.8, 1.8, 1.8), Palette.AwningRed, Palette.AwningWhite)
	gift(at(6.6, counterTop + 0.7, 0.1), Vector3.new(1.6, 1.4, 1.6), Palette.GiftGreen, Palette.Gold)
	gift(at(5.3, counterTop + 2.3, 0.3) * CFrame.Angles(0, 0.4, 0), Vector3.new(1.1, 1, 1.1), Palette.Gold, Palette.AwningRed)

	-- In front of the counter: two crates leaning back against it and one upright.
	for _, x in { -7, -2.6 } do
		crate(at(x, 1.3, -3.3) * CFrame.Angles(math.rad(-28), 0, 0), Vector3.new(4.2, 2.2, 3), true)
	end
	crate(at(2.6, 1.1, -4.6) * CFrame.Angles(0, math.rad(8), 0), Vector3.new(3.6, 2.2, 3), true)
	gift(at(6.2, 0.8, -3.6) * CFrame.Angles(0, -0.3, 0), Vector3.new(1.8, 1.6, 1.8), Palette.GiftGreen, Palette.AwningRed)

	-- Santa leaning on the right end of the counter, his left arm resting on it.
	local santa = container("Model", "Santa", shop)
	local body = at(12.6, 0, -0.6) * CFrame.Angles(0, math.rad(-12), 0) * CFrame.Angles(0, 0, math.rad(9))
	local function piece(name: string, size: any, cframe: any, color: any)
		block(santa, size, cframe, color, { name = name, studs = false })
	end
	-- Legs, slightly apart.
	for _, x in { -0.5, 0.5 } do
		local leg = body * CFrame.new(x, 0, 0)
		piece("Boot", Vector3.new(1.04, 0.45, 1.12), leg * CFrame.new(0, 0.225, -0.04), Palette.Coal)
		piece("LegFur", Vector3.new(1.06, 0.32, 1.06), leg * CFrame.new(0, 0.6, 0), Palette.AwningWhite)
		piece("Leg", Vector3.new(1, 1.25, 1), leg * CFrame.new(0, 1.375, 0), Palette.SantaRed)
	end
	-- Torso: red coat, white centre strip and hem, black belt with a gold buckle.
	piece("Torso", Vector3.new(2, 2, 1), body * CFrame.new(0, 3, 0), Palette.SantaRed)
	piece("CoatStrip", Vector3.new(0.5, 2, 0.1), body * CFrame.new(0, 3, -0.53), Palette.AwningWhite)
	piece("Hem", Vector3.new(2.08, 0.28, 1.08), body * CFrame.new(0, 2.14, 0), Palette.AwningWhite)
	piece("Belt", Vector3.new(2.06, 0.36, 1.06), body * CFrame.new(0, 2.55, 0), Palette.Coal)
	piece("Buckle", Vector3.new(0.6, 0.48, 0.1), body * CFrame.new(0, 2.55, -0.58), Palette.Gold)
	-- Arms hang from a pivot at the top of the shoulder.
	local function arm(side: number, angle: number)
		local shoulder = body * CFrame.new(side * 1.5, 4, 0) * CFrame.Angles(0, 0, angle)
		piece("Arm", Vector3.new(1, 1.25, 1), shoulder * CFrame.new(0, -0.625, 0), Palette.SantaRed)
		piece("ArmFur", Vector3.new(1.06, 0.32, 1.06), shoulder * CFrame.new(0, -1.4, 0), Palette.AwningWhite)
		piece("Hand", Vector3.new(0.9, 0.5, 0.9), shoulder * CFrame.new(0, -1.8, 0), Palette.Skin)
	end
	arm(-1, math.rad(-95)) -- left arm laid along the counter top
	arm(1, math.rad(4))
	-- Head with eyes, nose, beard and moustache.
	local head = body * CFrame.new(0, 4.65, 0)
	piece("Head", Vector3.new(1.3, 1.3, 1.3), head, Palette.Skin)
	for _, x in { -0.28, 0.28 } do
		piece("Eye", Vector3.new(0.18, 0.26, 0.1), head * CFrame.new(x, 0.2, -0.66), Palette.Coal)
	end
	piece("Beard", Vector3.new(1.42, 0.8, 0.4), head * CFrame.new(0, -0.38, -0.55), Palette.AwningWhite)
	piece("Beard", Vector3.new(1.1, 0.55, 0.45), head * CFrame.new(0, -0.95, -0.5), Palette.AwningWhite)
	piece("Moustache", Vector3.new(1, 0.28, 0.18), head * CFrame.new(0, -0.05, -0.78), Palette.AwningWhite)
	piece("Nose", Vector3.new(0.28, 0.24, 0.2), head * CFrame.new(0, 0.08, -0.85), Color3.fromRGB(232, 150, 136))
	-- Hat: fur brim, red cap and a tip flopping to one side with a pom-pom.
	piece("HatBrim", Vector3.new(1.55, 0.36, 1.55), head * CFrame.new(0, 0.72, 0), Palette.AwningWhite)
	piece("Hat", Vector3.new(1.3, 0.6, 1.3), head * CFrame.new(0, 1.18, 0), Palette.SantaRed)
	piece("HatTip", Vector3.new(0.8, 0.55, 0.8), head * CFrame.new(0.25, 1.6, 0.05) * CFrame.Angles(0, 0, math.rad(-25)), Palette.SantaRed)
	piece("PomPom", Vector3.new(0.48, 0.48, 0.48), head * CFrame.new(0.72, 1.62, 0.05), Palette.AwningWhite)
end

local Spawn = {}

function Spawn.build(): any
	local model = container("Model", "Spawn")
	local cells = buildHeightmap()

	buildGround(container("Folder", "Ground", model), cells)
	buildBoundary(container("Folder", "Boundary", model), cells)
	buildTiles(container("Folder", "Plaza", model))
	buildSpawnPoints(model)
	buildFrozenFountain(model)

	local benches = container("Folder", "Benches", model)
	for _, x in { -30, 30 } do
		for _, z in { FOUNTAIN_CENTER.Z - 12, FOUNTAIN_CENTER.Z + 12 } do
			local base = Vector3.new(x, TILE_HEIGHT, z)
			buildBench(benches, base, Vector3.new(-x, 0, 0).Unit)
		end
	end

	local lamps = container("Folder", "Lamps", model)
	local plazaX = (PLAZA.x1 + 1) * VOXEL - 4
	for _, x in { -plazaX, plazaX } do
		for _, z in { PLAZA.z0 * VOXEL + 4, (PLAZA.z1 + 1) * VOXEL - 4 } do
			buildLamp(lamps, Vector3.new(x, TILE_HEIGHT, z))
		end
	end
	for _, z in { 8, 3, -2 } do
		local c = pathCenter(z)
		buildLamp(lamps, Vector3.new((c - 2) * VOXEL - 2, 0, z * VOXEL + 2))
		buildLamp(lamps, Vector3.new((c + 2) * VOXEL + 2, 0, z * VOXEL + 2))
	end
	for _, x in { -10, 10 } do
		buildLamp(lamps, Vector3.new(x, 0, (CANYON_START + 2.5) * VOXEL))
	end

	buildSnowField(model)
	buildZones(model)
	buildGate(model)
	buildSnowballStatue(model)
	buildShop(model)
	buildDecorations(container("Folder", "Decorations", model), cells)

	return model
end

return Spawn
