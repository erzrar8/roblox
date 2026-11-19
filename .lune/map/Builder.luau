--!strict
-- Shared helpers for map generation. These scripts run in Lune (`lune run build-map`), not inside Roblox.

local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local Builder = {}

Builder.Palette = {
	Snow = Color3.fromRGB(236, 243, 250),
	SnowShade = Color3.fromRGB(218, 230, 244),
	FieldSnow = Color3.fromRGB(246, 250, 255),
	-- Snow field: fresh snow on top, packed snow underneath shows where a snowball has rolled.
	FreshSnow = Color3.fromRGB(250, 252, 255),
	PackedSnow = Color3.fromRGB(192, 210, 234),
	Wood = Color3.fromRGB(138, 96, 64),
	WoodLight = Color3.fromRGB(184, 136, 90),
	WoodDark = Color3.fromRGB(104, 70, 46),
	AwningRed = Color3.fromRGB(206, 38, 42),
	AwningWhite = Color3.fromRGB(250, 250, 250),
	SantaRed = Color3.fromRGB(190, 28, 34),
	Skin = Color3.fromRGB(240, 196, 160),
	Gold = Color3.fromRGB(242, 196, 58),
	GiftGreen = Color3.fromRGB(46, 150, 82),
	-- Elf Village
	Gingerbread = Color3.fromRGB(184, 110, 58),
	GingerDark = Color3.fromRGB(132, 74, 36),
	Chocolate = Color3.fromRGB(94, 54, 32),
	Icing = Color3.fromRGB(255, 255, 255),
	CandyRed = Color3.fromRGB(226, 40, 52),
	CandyPacked = Color3.fromRGB(238, 200, 222),
	CandyPink = Color3.fromRGB(255, 176, 212),
	CandyMint = Color3.fromRGB(164, 238, 210),
	CandyLemon = Color3.fromRGB(255, 238, 150),
	CandyLavender = Color3.fromRGB(212, 188, 255),
	CandySky = Color3.fromRGB(170, 220, 255),
	VillageTile = Color3.fromRGB(244, 228, 204),
	VillageTileAlt = Color3.fromRGB(240, 204, 210),
	TreeGreen = Color3.fromRGB(40, 132, 70),
	TreeGreenLight = Color3.fromRGB(56, 158, 84),
	ElfGreen = Color3.fromRGB(46, 164, 62),
	ElfHat = Color3.fromRGB(96, 222, 70),
	ElfYellow = Color3.fromRGB(250, 210, 64),
	ElfYellowLight = Color3.fromRGB(255, 240, 150),
	ElfShoe = Color3.fromRGB(62, 40, 30),
	WindowGlow = Color3.fromRGB(255, 206, 120),
	Dirt = Color3.fromRGB(96, 68, 54),
	Grout = Color3.fromRGB(118, 133, 158),
	Tile = Color3.fromRGB(178, 192, 214),
	TileAlt = Color3.fromRGB(164, 180, 204),
	TileDark = Color3.fromRGB(140, 156, 182),
	Trunk = Color3.fromRGB(92, 82, 54),
	Rock = Color3.fromRGB(128, 136, 150),
	Ice = Color3.fromRGB(166, 214, 246),
	IceDark = Color3.fromRGB(128, 188, 232),
	LampPost = Color3.fromRGB(58, 64, 80),
	LampLight = Color3.fromRGB(255, 214, 140),
	Sign = Color3.fromRGB(44, 66, 110),
	Coal = Color3.fromRGB(30, 30, 36),
	Carrot = Color3.fromRGB(244, 132, 40),
}

export type BlockOptions = {
	name: string?,
	transparency: number?,
	reflectance: number?,
	canCollide: boolean?,
	studs: boolean?,
	material: any?,
}

local FACES = { "Top", "Bottom", "Front", "Back", "Left", "Right" }

function Builder.block(parent: any, size: any, cframe: any, color: any, options: BlockOptions?): any
	local opts: BlockOptions = options or {}
	local part = Instance.new("Part")
	part.Name = opts.name or "Block"
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.material or Enum.Material.Plastic
	part.Transparency = opts.transparency or 0
	part.Reflectance = opts.reflectance or 0
	part.CanCollide = if opts.canCollide == nil then true else opts.canCollide
	local surface = if opts.studs == false then Enum.SurfaceType.Smooth else Enum.SurfaceType.Studs
	for _, face in FACES do
		part[face .. "Surface"] = surface
	end
	part.Parent = parent
	return part
end

-- Axis-aligned block spanning two corners.
function Builder.box(parent: any, min: any, max: any, color: any, options: BlockOptions?): any
	local size = max - min
	return Builder.block(parent, size, CFrame.new(min + size / 2), color, options)
end

function Builder.container(className: string, name: string, parent: any?): any
	local instance = Instance.new(className)
	instance.Name = name
	if parent then
		instance.Parent = parent
	end
	return instance
end

export type Rng = {
	next: () -> number,
	range: (min: number, max: number) -> number,
	int: (min: number, max: number) -> number,
	chance: (p: number) -> boolean,
}

-- Deterministic Park-Miller RNG so the map is identical on every rebuild.
function Builder.rng(seed: number): Rng
	local state = seed % 2147483646 + 1
	local rng = {} :: Rng
	function rng.next()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function rng.range(min, max)
		return min + (max - min) * rng.next()
	end
	function rng.int(min, max)
		return min + math.floor(rng.next() * (max - min + 1))
	end
	function rng.chance(p)
		return rng.next() < p
	end
	return rng
end

export type Rect = { x0: number, x1: number, z0: number, z1: number, key: string }

-- Merges grid cells with equal keys into as few rectangles as possible (keeps part count low).
function Builder.greedyRects(minX: number, maxX: number, minZ: number, maxZ: number, keyAt: (number, number) -> string?): { Rect }
	local used: { [string]: boolean } = {}
	local function free(x: number, z: number, key: string): boolean
		return keyAt(x, z) == key and not used[`{x},{z}`]
	end

	local rects = {}
	for z = minZ, maxZ do
		for x = minX, maxX do
			local key = keyAt(x, z)
			if key and not used[`{x},{z}`] then
				local x1 = x
				while x1 < maxX and free(x1 + 1, z, key) do
					x1 += 1
				end
				local z1 = z
				while z1 < maxZ do
					local rowFree = true
					for xx = x, x1 do
						if not free(xx, z1 + 1, key) then
							rowFree = false
							break
						end
					end
					if not rowFree then
						break
					end
					z1 += 1
				end
				for zz = z, z1 do
					for xx = x, x1 do
						used[`{xx},{zz}`] = true
					end
				end
				table.insert(rects, { x0 = x, x1 = x1, z0 = z, z1 = z1, key = key })
			end
		end
	end
	return rects
end

return Builder
