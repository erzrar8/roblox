--!strict
-- Zone 1, the Elf Village: a snowy basin north of the Zone 1 gate with a candy-snow field (worth 3x),
-- gingerbread houses, glowing lanterns, giant candy canes, a big Christmas tree and three elves who
-- hand out missions. Spawn.luau owns the terrain; this module provides the village layout and builds
-- everything standing on it.
--
-- Same grid as Spawn.luau: 1 cell = 4 studs, cell (x, z) covers X in [4x, 4x+4], Z in [4z, 4z+4].

local roblox = require("@lune/roblox")
local Builder = require("./Builder")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local Palette = Builder.Palette
local block, box, container = Builder.block, Builder.box, Builder.container

type Area = { x0: number, x1: number, z0: number, z1: number }

local VOXEL = 4
local TILE_HEIGHT = 0.4
local SEED = 2027

local Village = {}

-- Basin (in cells), a rounded rectangle like the spawn island.
Village.RX, Village.RZ, Village.CZ = 32.5, 30.5, -106
-- Only this outer part of the basin gets terraces; the village itself is flat.
Village.RIM = 0.88
Village.PLAZA = { x0 = -8, x1 = 7, z0 = -90, z1 = -80 } :: Area
Village.FIELD = { x0 = -20, x1 = 19, z0 = -125, z1 = -96 } :: Area
-- Paved path from the canyon, through the plaza, to the candy field.
Village.PATH_Z0, Village.PATH_Z1 = Village.FIELD.z1 + 1, -78
Village.BOUNDS = { x0 = -33, x1 = 32, z0 = -137, z1 = -76 } :: Area

local TREE_CENTER = Vector3.new(0, TILE_HEIGHT, -338)

type HouseSpec = { position: any, facing: any }
local HOUSES: { HouseSpec } = {
	{ position = Vector3.new(-52, 0, -324), facing = Vector3.new(1, 0, 0) },
	{ position = Vector3.new(-52, 0, -352), facing = Vector3.new(1, 0, 0) },
	{ position = Vector3.new(52, 0, -324), facing = Vector3.new(-1, 0, 0) },
	{ position = Vector3.new(52, 0, -352), facing = Vector3.new(-1, 0, 0) },
	{ position = Vector3.new(-102, 0, -440), facing = Vector3.new(1, 0, 0) },
	{ position = Vector3.new(102, 0, -440), facing = Vector3.new(-1, 0, 0) },
}

type ElfSpec = { id: string, name: string, from: any, to: any }
-- Elves pace between two points; ids must match src/shared/Missions.luau.
local ELVES: { ElfSpec } = {
	{ id = "Jingle", name = "Jingle", from = Vector3.new(-39, 0, -320), to = Vector3.new(-39, 0, -356) },
	{ id = "Tinsel", name = "Tinsel", from = Vector3.new(39, 0, -320), to = Vector3.new(39, 0, -356) },
	{ id = "Sprinkles", name = "Sprinkles", from = Vector3.new(14, 0, -369), to = Vector3.new(34, 0, -369) },
}

local CANDY_COLORS = { Palette.CandyPink, Palette.CandyMint, Palette.CandyLemon, Palette.CandyLavender, Palette.CandySky }
local GUMDROPS = { Palette.CandyRed, Palette.GiftGreen, Palette.ElfYellow, Color3.fromRGB(150, 90, 230), Color3.fromRGB(60, 150, 240) }
local ORNAMENTS = { Palette.CandyRed, Palette.Gold, Color3.fromRGB(70, 150, 255), Color3.fromRGB(240, 110, 210) }
local LANTERNS = { Palette.CandyRed, Palette.ElfYellow, Palette.GiftGreen }

local function inArea(area: Area, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= area.x0 - m and x <= area.x1 + m and z >= area.z0 - m and z <= area.z1 + m
end

function Village.distance(x: number, z: number, grow: number?): number
	local g = grow or 0
	local nx = (x + 0.5) / (Village.RX + g)
	local nz = (z + 0.5 - Village.CZ) / (Village.RZ + g)
	return (nx ^ 4 + nz ^ 4) ^ 0.25
end

function Village.isPath(x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x >= -2 - m and x <= 1 + m and z >= Village.PATH_Z0 and z <= Village.PATH_Z1
end

local function isHouse(x: number, z: number): boolean
	for _, house in HOUSES do
		local hx, hz = house.position.X // VOXEL, house.position.Z // VOXEL
		if math.abs(x - hx) <= 3 and math.abs(z - hz) <= 3 then
			return true
		end
	end
	return false
end

-- Cells that must stay flat (plaza, field, path, house plots).
function Village.isFlat(x: number, z: number): boolean
	return inArea(Village.PLAZA, x, z, 1) or inArea(Village.FIELD, x, z, 1) or Village.isPath(x, z, 1) or isHouse(x, z)
end

-- Ground kind for a cell inside the basin: stone, candy (field), villagesnow (kept clear) or snow (rim).
function Village.kindAt(x: number, z: number): string
	if inArea(Village.PLAZA, x, z) or Village.isPath(x, z) then
		return "stone"
	elseif inArea(Village.FIELD, x, z) then
		return "candy"
	elseif Village.distance(x, z) <= Village.RIM or Village.isFlat(x, z) then
		return "villagesnow"
	end
	return "snow"
end

local function cellCenter(x: number, z: number, y: number): any
	return Vector3.new(x * VOXEL + VOXEL / 2, y, z * VOXEL + VOXEL / 2)
end

local function facingFrame(position: any, facing: any): any
	return CFrame.new(position) * CFrame.Angles(0, math.atan2(-facing.X, -facing.Z), 0)
end

-- Local builder: parts placed relative to `origin`.
local function kit(parent: any, origin: any)
	return function(name: string, size: any, offset: any, color: any, options: Builder.BlockOptions?): any
		local opts: Builder.BlockOptions = options or {}
		opts.name = name
		local cf = if typeof(offset) == "CFrame" then origin * offset else origin * CFrame.new(offset)
		return block(parent, size, cf, color, opts)
	end
end

local function buildTiles(parent: any)
	local rng = Builder.rng(SEED)
	local function tile(x: number, z: number, color: any)
		block(parent, Vector3.new(3.6, TILE_HEIGHT, 3.6), CFrame.new(cellCenter(x, z, TILE_HEIGHT / 2)), color, { name = "Tile" })
	end
	local function paving(): any
		return if rng.chance(0.35) then Palette.VillageTileAlt else Palette.VillageTile
	end
	local P = Village.PLAZA
	for x = P.x0, P.x1 do
		for z = P.z0, P.z1 do
			local onEdge = x == P.x0 or x == P.x1 or z == P.z0 or z == P.z1
			local opening = (z == P.z0 or z == P.z1) and x >= -2 and x <= 1
			tile(x, z, if onEdge and not opening then Palette.Chocolate else paving())
		end
	end
	for z = Village.PATH_Z1, Village.PATH_Z0, -1 do
		if not inArea(P, 0, z) then
			for x = -2, 1 do
				tile(x, z, if x == -2 or x == 1 then Palette.Chocolate else paving())
			end
		end
	end
end

local function candyCane(parent: any, base: any, scale: number, facing: any)
	local model = container("Model", "CandyCane", parent)
	local p = kit(model, facingFrame(base, facing))
	local u = scale
	local spots = {}
	for i = 0, 6 do
		table.insert(spots, Vector3.new(0, (i + 0.5) * u, 0))
	end
	for _, spot in { Vector3.new(0.9, 7.2, 0), Vector3.new(1.8, 7.0, 0), Vector3.new(2.2, 6.1, 0), Vector3.new(2.2, 5.2, 0) } do
		table.insert(spots, spot * u)
	end
	for i, spot in spots do
		p("Cane", Vector3.new(u, u, u), spot, if i % 2 == 0 then Palette.Icing else Palette.CandyRed)
	end
end

local function lantern(parent: any, base: any, color: any)
	local model = container("Model", "Lantern", parent)
	local p = kit(model, CFrame.new(base))
	p("Base", Vector3.new(1.6, 0.8, 1.6), Vector3.new(0, 0.4, 0), Palette.Chocolate)
	p("Post", Vector3.new(0.6, 6.4, 0.6), Vector3.new(0, 4, 0), Palette.Chocolate)
	p("CapBottom", Vector3.new(1.6, 0.35, 1.6), Vector3.new(0, 7.3, 0), Palette.Gold, { studs = false })
	local glow = p("Paper", Vector3.new(1.4, 1.9, 1.4), Vector3.new(0, 8.4, 0), color, { material = Enum.Material.Neon, studs = false })
	p("CapTop", Vector3.new(1.6, 0.35, 1.6), Vector3.new(0, 9.5, 0), Palette.Gold, { studs = false })
	p("Snow", Vector3.new(1.9, 0.4, 1.9), Vector3.new(0, 9.85, 0), Palette.Snow)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.1
	light.Parent = glow
end

local function gift(p: any, offset: any, size: any, color: any, ribbon: any)
	p("Gift", size, offset, color, { studs = false })
	p("Ribbon", Vector3.new(size.X + 0.06, size.Y + 0.06, 0.3), offset, ribbon, { studs = false })
	p("Ribbon", Vector3.new(0.3, size.Y + 0.06, size.Z + 0.06), offset, ribbon, { studs = false })
end

local function christmasTree(parent: any)
	local model = container("Model", "ChristmasTree", parent)
	local rng = Builder.rng(SEED + 1)
	local p = kit(model, CFrame.new(TREE_CENTER))
	p("Trunk", Vector3.new(2.4, 2.6, 2.4), Vector3.new(0, 1.3, 0), Palette.Trunk)
	local tiers = { { 15, 3.6 }, { 12, 3.6 }, { 9, 3.6 }, { 6.2, 3.4 }, { 3.4, 3 } }
	local y = 2.4
	for i, tier in tiers do
		local w, h = tier[1], tier[2]
		p("Tier", Vector3.new(w, h, w), Vector3.new(0, y + h / 2, 0), if i % 2 == 0 then Palette.TreeGreenLight else Palette.TreeGreen)
		p("TierSnow", Vector3.new(w + 0.2, 0.4, w + 0.2), Vector3.new(0, y + h - 0.2, 0), Palette.Snow)
		if w > 4 then
			for k = 0, 7 do
				local side = k % 4
				local along = rng.range(-w / 2 + 0.8, w / 2 - 0.8)
				local out = w / 2 + 0.3
				local offset = if side == 0 then Vector3.new(along, 0, -out)
					elseif side == 1 then Vector3.new(out, 0, along)
					elseif side == 2 then Vector3.new(along, 0, out)
					else Vector3.new(-out, 0, along)
				local ornament = p("Ornament", Vector3.new(0.9, 0.9, 0.9), offset + Vector3.new(0, y + rng.range(0.6, h - 1), 0), ORNAMENTS[rng.int(1, #ORNAMENTS)], {
					material = Enum.Material.Neon,
					studs = false,
				})
				ornament.CastShadow = false
			end
		end
		y += h
	end
	local star = p("Star", Vector3.new(2.2, 2.2, 0.7), CFrame.new(0, y + 1.1, 0) * CFrame.Angles(0, 0, math.rad(45)), Palette.Gold, {
		material = Enum.Material.Neon,
		studs = false,
	})
	p("Star", Vector3.new(2.2, 2.2, 0.7), CFrame.new(0, y + 1.1, 0), Palette.Gold, { material = Enum.Material.Neon, studs = false })
	local light = Instance.new("PointLight")
	light.Color = Palette.Gold
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = star

	local gifts = {
		{ Vector3.new(-6.5, 1, -5), Vector3.new(2, 2, 2), Palette.CandyRed, Palette.Icing },
		{ Vector3.new(6, 0.8, -5.5), Vector3.new(2.2, 1.6, 1.8), Palette.GiftGreen, Palette.Gold },
		{ Vector3.new(-5.5, 0.7, 6), Vector3.new(1.6, 1.4, 1.6), Palette.Gold, Palette.CandyRed },
		{ Vector3.new(6.2, 1.1, 5.4), Vector3.new(1.8, 2.2, 1.8), Color3.fromRGB(60, 150, 240), Palette.Icing },
	}
	for _, g in gifts do
		gift(p, g[1], g[2], g[3], g[4])
	end
end

local function house(parent: any, spec: HouseSpec, rng: Builder.Rng)
	local model = container("Model", "GingerbreadHouse", parent)
	local p = kit(model, facingFrame(spec.position, spec.facing))
	local W, D = 12, 10

	p("Base", Vector3.new(W + 0.6, 1, D + 0.6), Vector3.new(0, 0.5, 0), Palette.GingerDark)
	p("Walls", Vector3.new(W, 8, D), Vector3.new(0, 5, 0), Palette.Gingerbread)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			p("Icing", Vector3.new(0.8, 8, 0.8), Vector3.new(sx * W / 2, 5, sz * D / 2), Palette.Icing)
		end
	end
	-- Icing dripping from the eaves, front and back.
	for _, sz in { -1, 1 } do
		for i = -5, 5 do
			local h = rng.range(0.5, 1.3)
			p("Drip", Vector3.new(0.9, h, 0.3), Vector3.new(i, 9 - h / 2, sz * (D / 2 + 0.15)), Palette.Icing, { studs = false })
		end
	end

	-- Door with an icing frame.
	p("Door", Vector3.new(3, 5, 0.4), Vector3.new(0, 3.5, -D / 2 - 0.1), Palette.Chocolate)
	p("DoorFrame", Vector3.new(3.9, 0.6, 0.5), Vector3.new(0, 6.25, -D / 2 - 0.15), Palette.Icing)
	for _, sx in { -1, 1 } do
		p("DoorFrame", Vector3.new(0.5, 5, 0.5), Vector3.new(sx * 1.75, 3.5, -D / 2 - 0.15), Palette.Icing)
	end
	p("Knob", Vector3.new(0.4, 0.4, 0.3), Vector3.new(0.9, 3.5, -D / 2 - 0.4), Palette.Gold, { studs = false })

	-- Glowing windows: two at the front, one on each side.
	local function window(offset: any, sideways: boolean)
		local frame = if sideways then Vector3.new(0.25, 2.9, 2.9) else Vector3.new(2.9, 2.9, 0.25)
		local glass = if sideways then Vector3.new(0.3, 2.2, 2.2) else Vector3.new(2.2, 2.2, 0.3)
		local out = if sideways then Vector3.new(math.sign(offset.X) * 0.08, 0, 0) else Vector3.new(0, 0, -0.08)
		p("WindowFrame", frame, offset, Palette.Icing)
		p("Window", glass, offset + out, Palette.WindowGlow, { material = Enum.Material.Neon, studs = false })
		local bar = if sideways then Vector3.new(0.35, 2.2, 0.25) else Vector3.new(0.25, 2.2, 0.35)
		local bar2 = if sideways then Vector3.new(0.35, 0.25, 2.2) else Vector3.new(2.2, 0.25, 0.35)
		p("WindowBar", bar, offset + out * 2, Palette.Icing, { studs = false })
		p("WindowBar", bar2, offset + out * 2, Palette.Icing, { studs = false })
	end
	window(Vector3.new(-3.9, 5, -D / 2 - 0.05), false)
	window(Vector3.new(3.9, 5, -D / 2 - 0.05), false)
	window(Vector3.new(-W / 2 - 0.05, 5, 0), true)
	window(Vector3.new(W / 2 + 0.05, 5, 0), true)

	-- Stepped chocolate roof with icing on every step and gumdrops along the ledges.
	local steps = { 14, 11, 8, 5, 2 }
	for i, width in steps do
		local y = 9 + (i - 1) * 1.4
		p("Roof", Vector3.new(width, 1.4, D + 2), Vector3.new(0, y + 0.7, 0), Palette.Chocolate)
		p("RoofIcing", Vector3.new(width + 0.1, 0.35, D + 2.1), Vector3.new(0, y + 1.4 + 0.17, 0), Palette.Icing)
		if i < #steps then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					p("Gumdrop", Vector3.new(0.9, 0.8, 0.9), Vector3.new(sx * (width / 2 - 0.75), y + 1.4 + 0.75, sz * (D / 2 + 0.4)), GUMDROPS[rng.int(1, #GUMDROPS)], {
						studs = false,
					})
				end
			end
		end
	end

	-- Candy-striped chimney with a puff of smoke.
	for i = 0, 3 do
		p("Chimney", Vector3.new(2.2, 2, 2.2), Vector3.new(3.6, 10 + i * 2, 2.2), if i % 2 == 0 then Palette.CandyRed else Palette.Icing)
	end
	p("ChimneyCap", Vector3.new(2.8, 0.6, 2.8), Vector3.new(3.6, 17.3, 2.2), Palette.Icing)
	for i, puff in { { 0, 18.8, 1.6 }, { 0.6, 20.4, 1.3 }, { 1.4, 21.9, 1 } } do
		local smoke = p("Smoke", Vector3.new(puff[3], puff[3] * 0.85, puff[3]), Vector3.new(3.6 + puff[1], puff[2], 2.2 + i * 0.3), Color3.fromRGB(232, 236, 242), {
			transparency = 0.25,
			canCollide = false,
			studs = false,
		})
		smoke.CastShadow = false
	end

	candyCane(model, (facingFrame(spec.position, spec.facing) * CFrame.new(2.9, 0, -D / 2 - 1.2)).Position, 0.55, spec.facing)
end

local function fieldFence(parent: any)
	local F = Village.FIELD
	local x0, x1 = F.x0 * VOXEL, (F.x1 + 1) * VOXEL
	local z0, z1 = F.z0 * VOXEL, (F.z1 + 1) * VOXEL
	local fence = container("Model", "CandyFence", parent)
	local function run(a: any, b: any)
		local delta = b - a
		local length = math.abs(delta.X) + math.abs(delta.Z)
		local posts = math.max(1, math.floor(length / 8 + 0.5))
		for i = 0, posts do
			local q = a + delta * (i / posts)
			block(fence, Vector3.new(1.2, 2, 1.2), CFrame.new(q + Vector3.new(0, 1, 0)), Palette.CandyRed, { name = "Post" })
			block(fence, Vector3.new(1.2, 2, 1.2), CFrame.new(q + Vector3.new(0, 3, 0)), Palette.Icing, { name = "Post" })
			block(fence, Vector3.new(1.4, 0.6, 1.4), CFrame.new(q + Vector3.new(0, 4.3, 0)), Palette.CandyRed, { name = "PostCap" })
		end
		local size = Vector3.new(math.abs(delta.X) + 0.5, 0.5, math.abs(delta.Z) + 0.5)
		for _, y in { 1.4, 2.9 } do
			block(fence, size, CFrame.new((a + b) / 2 + Vector3.new(0, y, 0)), Palette.CandyPink, { name = "Rail" })
		end
	end
	-- Opening on the plaza side.
	run(Vector3.new(x0, 0, z1), Vector3.new(-8, 0, z1))
	run(Vector3.new(8, 0, z1), Vector3.new(x1, 0, z1))
	run(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0))
	run(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1))
	run(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1))
end

-- Voxel elf after the reference: green coat with white collar and cuffs, black belt with a gold buckle,
-- yellow striped trousers, pointy ears and a bright green hat with a white brim. Parts carry a "Limb"
-- attribute so the client (src/client/Elves.luau) can swing arms and legs while the elf walks.
local function elf(parent: any, spec: ElfSpec)
	local s = 0.9
	local model = container("Model", "Elf", parent)
	model:SetAttribute("ElfId", spec.id)
	model:SetAttribute("ElfName", spec.name)
	model:SetAttribute("WalkFrom", spec.from)
	model:SetAttribute("WalkTo", spec.to)
	model:SetAttribute("HipY", 2.05 * s)
	model:SetAttribute("ShoulderY", 4.05 * s)

	local direction = (spec.to - spec.from).Unit
	local origin = facingFrame(spec.from, direction)
	local root = block(model, Vector3.new(1, 0.2, 1), origin * CFrame.new(0, 0.1, 0), Palette.ElfGreen, {
		name = "Root",
		transparency = 1,
		canCollide = false,
		studs = false,
	})
	model.PrimaryPart = root

	local function piece(name: string, size: any, offset: any, color: any, limb: string?)
		local cf = if typeof(offset) == "CFrame" then offset else CFrame.new(offset)
		local scaled = CFrame.new(cf.Position * s) * cf.Rotation
		local part = block(model, size * s, origin * scaled, color, { name = name, canCollide = false, studs = false })
		part.CanQuery = false
		part.CanTouch = false
		if limb then
			part:SetAttribute("Limb", limb)
		end
	end

	for _, side in { -1, 1 } do
		local limb = if side < 0 then "LegL" else "LegR"
		piece("Shoe", Vector3.new(1.05, 0.45, 1.3), Vector3.new(side * 0.5, 0.225, -0.12), Palette.ElfShoe, limb)
		for k = 0, 3 do
			piece("Leg", Vector3.new(1, 0.4, 1), Vector3.new(side * 0.5, 0.65 + k * 0.4, 0), if k % 2 == 0 then Palette.ElfYellow else Palette.ElfYellowLight, limb)
		end
	end
	piece("CoatHem", Vector3.new(2.15, 0.5, 1.12), Vector3.new(0, 2.25, 0), Palette.ElfGreen)
	piece("Torso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.3, 0), Palette.ElfGreen)
	piece("Belt", Vector3.new(2.06, 0.34, 1.06), Vector3.new(0, 2.62, 0), Palette.Coal)
	piece("Buckle", Vector3.new(0.62, 0.46, 0.1), Vector3.new(0, 2.62, -0.58), Palette.Gold)
	piece("Collar", Vector3.new(2.1, 0.35, 1.1), Vector3.new(0, 3.95, 0), Palette.Icing)
	for _, side in { -1, 1 } do
		piece("CollarTip", Vector3.new(0.55, 0.42, 0.1), CFrame.new(side * 0.36, 3.68, -0.56) * CFrame.Angles(0, 0, side * math.rad(20)), Palette.Icing)
		piece("Button", Vector3.new(0.16, 0.16, 0.08), Vector3.new(side * 0.32, 3.1, -0.53), Palette.Gold)
	end
	for _, side in { -1, 1 } do
		local limb = if side < 0 then "ArmL" else "ArmR"
		piece("Sleeve", Vector3.new(1, 1.3, 1), Vector3.new(side * 1.5, 3.4, 0), Palette.ElfGreen, limb)
		piece("Cuff", Vector3.new(1.08, 0.32, 1.08), Vector3.new(side * 1.5, 2.6, 0), Palette.Icing, limb)
		piece("Hand", Vector3.new(0.9, 0.45, 0.9), Vector3.new(side * 1.5, 2.22, 0), Palette.Skin, limb)
	end
	piece("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.75, 0), Palette.Skin)
	for _, side in { -1, 1 } do
		piece("Eye", Vector3.new(0.16, 0.24, 0.1), Vector3.new(side * 0.27, 4.88, -0.66), Palette.Coal)
		piece("SmileCorner", Vector3.new(0.12, 0.12, 0.1), Vector3.new(side * 0.28, 4.55, -0.66), Palette.Coal)
		piece("Ear", Vector3.new(0.3, 0.5, 0.3), CFrame.new(side * 0.75, 4.85, 0) * CFrame.Angles(0, 0, -side * math.rad(28)), Palette.Skin)
		piece("EarTip", Vector3.new(0.2, 0.32, 0.2), CFrame.new(side * 0.95, 5.2, 0) * CFrame.Angles(0, 0, -side * math.rad(40)), Palette.Skin)
	end
	piece("Smile", Vector3.new(0.48, 0.12, 0.1), Vector3.new(0, 4.49, -0.66), Palette.Coal)
	piece("HatBrim", Vector3.new(1.55, 0.36, 1.55), Vector3.new(0, 5.5, 0), Palette.Icing)
	piece("Hat", Vector3.new(1.3, 0.6, 1.3), Vector3.new(0, 5.95, 0), Palette.ElfHat)
	piece("HatTip", Vector3.new(0.9, 0.55, 0.9), CFrame.new(0, 6.45, 0.15) * CFrame.Angles(math.rad(14), 0, 0), Palette.ElfHat)
	piece("HatTip", Vector3.new(0.5, 0.45, 0.5), CFrame.new(0, 6.85, 0.45) * CFrame.Angles(math.rad(30), 0, 0), Palette.ElfHat)

	-- Fixed spot for the server's "Talk" prompt, halfway along the elf's walk (the elf moves client-side).
	local talk = block(model, Vector3.new(2, 2, 2), CFrame.new((spec.from + spec.to) / 2 + Vector3.new(0, 3, 0)), Palette.ElfGreen, {
		name = "TalkSpot",
		transparency = 1,
		canCollide = false,
		studs = false,
	})
	talk.CanQuery = false
	talk.CanTouch = false
end

function Village.candyColor(rng: Builder.Rng): any
	return CANDY_COLORS[rng.int(1, #CANDY_COLORS)]
end

function Village.build(parent: any)
	local village = container("Model", "Village", parent)
	local rng = Builder.rng(SEED + 2)

	buildTiles(container("Folder", "Tiles", village))
	christmasTree(village)
	fieldFence(village)

	local houses = container("Folder", "Houses", village)
	for _, spec in HOUSES do
		house(houses, spec, rng)
	end

	local lanterns = container("Folder", "Lanterns", village)
	local spots = {
		Vector3.new(-30, TILE_HEIGHT, -318),
		Vector3.new(30, TILE_HEIGHT, -318),
		Vector3.new(-30, TILE_HEIGHT, -358),
		Vector3.new(30, TILE_HEIGHT, -358),
		Vector3.new(-10, 0, -372),
		Vector3.new(10, 0, -372),
		Vector3.new(-84, 0, -384),
		Vector3.new(84, 0, -384),
		Vector3.new(-84, 0, -440),
		Vector3.new(84, 0, -440),
		Vector3.new(-84, 0, -496),
		Vector3.new(84, 0, -496),
	}
	for i, spot in spots do
		lantern(lanterns, spot, LANTERNS[(i - 1) % #LANTERNS + 1])
	end

	local canes = container("Folder", "CandyCanes", village)
	for _, side in { -1, 1 } do
		candyCane(canes, Vector3.new(side * 13, 0, -312), 1.6, Vector3.new(0, 0, 1))
		candyCane(canes, Vector3.new(side * 13, 0, -378), 1.1, Vector3.new(0, 0, 1))
	end

	local elves = container("Model", "Elves", village)
	elves.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, spec in ELVES do
		elf(elves, spec)
	end

	return village
end

return Village
