--!strict
-- Upgrade definitions, shared by the server (prices, effects) and the client (upgrades window).
-- A player's level of each upgrade is the player attribute "Upgrade_<id>", set by the server.
local Format = require(script.Parent.Format)

export type Definition = {
	id: string,
	name: string,
	icon: string, -- icon kind drawn by the client UI kit
	baseCost: number,
	costGrowth: number,
	maxLevel: number,
	base: number, -- value at level 0
	step: number, -- value added per level
	format: (value: number) -> string,
}

local function studs(value: number): string
	return `{math.floor(value + 0.5)} studs`
end

local Upgrades = {}

Upgrades.list = {
	{
		id = "SnowPower",
		name = "Snow Power",
		icon = "snowball",
		baseCost = 40,
		costGrowth = 1.55,
		maxLevel = 50,
		base = 1,
		step = 0.25,
		format = Format.multiplier,
	},
	{
		id = "BallCapacity",
		name = "Ball Size",
		icon = "bigball",
		baseCost = 80,
		costGrowth = 1.75,
		maxLevel = 20,
		base = 20,
		step = 4,
		format = studs,
	},
	{
		id = "SpeedBoost",
		name = "Speed Boost",
		icon = "boot",
		baseCost = 60,
		costGrowth = 1.7,
		maxLevel = 10,
		base = 1,
		step = 0.08,
		format = Format.multiplier,
	},
	{
		id = "CashMultiplier",
		name = "Cash Bonus",
		icon = "cash",
		baseCost = 100,
		costGrowth = 1.6,
		maxLevel = 50,
		base = 1,
		step = 0.2,
		format = Format.multiplier,
	},
} :: { Definition }

Upgrades.byId = {} :: { [string]: Definition }
for _, definition in Upgrades.list do
	Upgrades.byId[definition.id] = definition
end

function Upgrades.attribute(id: string): string
	return "Upgrade_" .. id
end

function Upgrades.level(player: Player, id: string): number
	local level = player:GetAttribute(Upgrades.attribute(id))
	return if typeof(level) == "number" then level else 0
end

function Upgrades.value(id: string, level: number): number
	local definition = Upgrades.byId[id]
	return definition.base + definition.step * level
end

-- The effect of `id` for this player at their current level.
function Upgrades.valueFor(player: Player, id: string): number
	return Upgrades.value(id, Upgrades.level(player, id))
end

-- Price of buying the next level when at `level`.
function Upgrades.cost(id: string, level: number): number
	local definition = Upgrades.byId[id]
	return math.floor(definition.baseCost * definition.costGrowth ^ level + 0.5)
end

return Upgrades
