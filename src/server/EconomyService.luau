--!strict
-- Money, selling snowballs and buying upgrades. Clients call the RemoteFunctions in
-- ReplicatedStorage.Remotes; everything is checked here on the server.
--
-- Player attributes: Money (coins), Upgrade_<id> (level of each upgrade, see Shared.Upgrades).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SnowballConfig"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local SnowballService = require(script.Parent.SnowballService)

local REQUEST_COOLDOWN = 0.25

export type Result = { ok: boolean, amount: number?, level: number?, reason: string? }

local EconomyService = {}

local lastRequest: { [Player]: number } = {}

local function setup(player: Player)
	if player:GetAttribute("Money") == nil then
		player:SetAttribute("Money", 0)
	end
	for _, definition in Upgrades.list do
		local attribute = Upgrades.attribute(definition.id)
		if player:GetAttribute(attribute) == nil then
			player:SetAttribute(attribute, 0)
		end
	end
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function money(player: Player): number
	local value = player:GetAttribute("Money")
	return if typeof(value) == "number" then value else 0
end

function EconomyService.sell(player: Player): Result
	if throttled(player) then
		return { ok = false, reason = "busy" }
	end
	local amount = Config.sellValue(SnowballService.collectedSnow(player), Upgrades.valueFor(player, "CashMultiplier"))
	if amount <= 0 then
		return { ok = false, reason = "empty" }
	end
	SnowballService.reset(player)
	player:SetAttribute("Money", money(player) + amount)
	return { ok = true, amount = amount }
end

function EconomyService.buyUpgrade(player: Player, id: unknown): Result
	if throttled(player) then
		return { ok = false, reason = "busy" }
	end
	if typeof(id) ~= "string" or not Upgrades.byId[id] then
		return { ok = false, reason = "unknown" }
	end
	local level = Upgrades.level(player, id)
	if level >= Upgrades.byId[id].maxLevel then
		return { ok = false, reason = "maxed" }
	end
	local cost = Upgrades.cost(id, level)
	local balance = money(player)
	if balance < cost then
		return { ok = false, reason = "poor" }
	end
	player:SetAttribute("Money", balance - cost)
	player:SetAttribute(Upgrades.attribute(id), level + 1)
	return { ok = true, level = level + 1 }
end

function EconomyService.start()
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	local sell = Instance.new("RemoteFunction")
	sell.Name = "Sell"
	sell.OnServerInvoke = function(player: Player)
		return EconomyService.sell(player)
	end
	sell.Parent = remotes
	local buy = Instance.new("RemoteFunction")
	buy.Name = "BuyUpgrade"
	buy.OnServerInvoke = function(player: Player, id: unknown)
		return EconomyService.buyUpgrade(player, id)
	end
	buy.Parent = remotes
	remotes.Parent = ReplicatedStorage

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return EconomyService
