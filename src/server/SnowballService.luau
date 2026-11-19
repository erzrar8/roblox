--!strict
-- Snowball rolling. While a player walks across a snow field, their ball (drawn by each client from
-- the attributes below) collects the fresh snow it rolls over and grows up to the Ball Size upgrade's
-- limit; bigger balls slow the player down. Snow fields are the zone parts with a "SnowValue"
-- attribute: the spawn Snow Field (1) and the Elf Village's Candy Field (3). The ball remembers what
-- its snow is worth, so candy snow sells for more. Off the fields, including the spawn, the ball is put
-- away but keeps its size. EconomyService sells it.
--
-- Player attributes: SnowballSize (diameter in studs), SnowballActive (true while on a field).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SnowballConfig"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local Zones = require(Shared:WaitForChild("Zones"))
local SnowLayer = require(script.Parent.SnowLayer)

local TICK = 0.1
-- Per tick, the player must move at least MIN_STEP studs for the ball to roll; longer jumps
-- (respawns, teleports) are ignored.
local MIN_STEP, MAX_STEP = 0.2, 10
local FLAT = Vector3.new(1, 0, 1)

-- Called with (player, field name, fresh snow tiles collected) whenever a ball picks up snow.
export type CollectedListener = (Player, string, number) -> ()

local SnowballService = {}

local volumes: { [Player]: number } = {}
-- Worth of the snow in each ball: collected snow (studs³) times its field's SnowValue.
local values: { [Player]: number } = {}
local lastPositions: { [Player]: Vector3 } = {}
local fields: { BasePart } = {}
local collectedListeners: { CollectedListener } = {}

local function setup(player: Player)
	volumes[player] = Config.volumeFromDiameter(Config.START_DIAMETER)
	values[player] = 0
	player:SetAttribute("SnowballSize", Config.START_DIAMETER)
	player:SetAttribute("SnowballActive", false)
end

local function fieldAt(position: Vector3): BasePart?
	for _, field in fields do
		if Zones.contains(field, position) then
			return field
		end
	end
	return nil
end

local function update(player: Player)
	local volume = volumes[player]
	if not volume then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		lastPositions[player] = nil
		player:SetAttribute("SnowballActive", false)
		return
	end

	local position = root.Position
	local field = if humanoid.Health > 0 then fieldAt(position) else nil
	local active = field ~= nil
	if player:GetAttribute("SnowballActive") ~= active then
		player:SetAttribute("SnowballActive", active)
	end

	local diameter = Config.diameterFromVolume(volume)
	local last = lastPositions[player]
	lastPositions[player] = position
	if field and last and humanoid.FloorMaterial ~= Enum.Material.Air then
		local step = ((position - last) * FLAT).Magnitude
		local look = root.CFrame.LookVector * FLAT
		if step >= MIN_STEP and step <= MAX_STEP and look.Magnitude > 1e-3 then
			local center = position + look.Unit * Config.ballOffset(diameter)
			local collected = SnowLayer.collect(center, Config.collectRadius(diameter))
			if collected > 0 then
				local snow = collected * Config.SNOW_PER_TILE * Upgrades.valueFor(player, "SnowPower")
				local maxVolume = Config.volumeFromDiameter(Upgrades.valueFor(player, "BallCapacity"))
				local added = math.max(math.min(volume + snow, maxVolume) - volume, 0)
				if added > 0 then
					local snowValue = field:GetAttribute("SnowValue")
					volume += added
					volumes[player] = volume
					values[player] = (values[player] or 0) + added * (if typeof(snowValue) == "number" then snowValue else 1)
					diameter = Config.diameterFromVolume(volume)
					player:SetAttribute("SnowballSize", math.floor(diameter * 100 + 0.5) / 100)
				end
				for _, listener in collectedListeners do
					task.spawn(listener, player, field.Name, collected)
				end
			end
		end
	end

	local speedBoost = Upgrades.valueFor(player, "SpeedBoost")
	local walkSpeed = (if active then Config.walkSpeed(diameter) else Config.BASE_WALK_SPEED) * speedBoost
	if math.abs(humanoid.WalkSpeed - walkSpeed) > 0.05 then
		humanoid.WalkSpeed = walkSpeed
	end
end

-- What the snow in the player's ball is worth before the Cash Bonus (see Config.sellValue).
function SnowballService.collectedValue(player: Player): number
	return values[player] or 0
end

function SnowballService.diameter(player: Player): number
	local volume = volumes[player]
	return if volume then Config.diameterFromVolume(volume) else Config.START_DIAMETER
end

-- Back to a fresh starting ball (after selling).
function SnowballService.reset(player: Player)
	if volumes[player] then
		volumes[player] = Config.volumeFromDiameter(Config.START_DIAMETER)
		values[player] = 0
		player:SetAttribute("SnowballSize", Config.START_DIAMETER)
	end
end

function SnowballService.onCollected(listener: CollectedListener)
	table.insert(collectedListeners, listener)
end

function SnowballService.start()
	local spawnMap = Workspace:WaitForChild("Map"):WaitForChild("Spawn")
	for _, zone in spawnMap:WaitForChild("Zones"):GetChildren() do
		if zone:IsA("BasePart") and zone:GetAttribute("SnowValue") ~= nil then
			table.insert(fields, zone)
		end
	end
	SnowLayer.start(spawnMap:WaitForChild("FreshSnow"))

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		volumes[player] = nil
		values[player] = nil
		lastPositions[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				update(player)
			end
			task.wait(TICK)
		end
	end)
end

return SnowballService
