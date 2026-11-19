--!strict
-- Snowball rolling. While a player walks across the snow field, their ball (drawn by each client from
-- the attributes below) collects the fresh snow it rolls over and grows; bigger balls slow the player
-- down. Off the field, including the spawn, the ball is put away but keeps its size.
--
-- Player attributes: SnowballSize (diameter in studs), SnowballActive (true while on the field).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SnowballConfig"))
local Zones = require(Shared:WaitForChild("Zones"))
local SnowLayer = require(script.Parent.SnowLayer)

local TICK = 0.1
-- Per tick, the player must move at least MIN_STEP studs for the ball to roll; longer jumps
-- (respawns, teleports) are ignored.
local MIN_STEP, MAX_STEP = 0.2, 10
local FLAT = Vector3.new(1, 0, 1)

local SnowballService = {}

local volumes: { [Player]: number } = {}
local lastPositions: { [Player]: Vector3 } = {}

local function setup(player: Player)
	volumes[player] = Config.volumeFromDiameter(Config.START_DIAMETER)
	player:SetAttribute("SnowballSize", Config.START_DIAMETER)
	player:SetAttribute("SnowballActive", false)
end

local function update(player: Player, field: BasePart)
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
	local active = humanoid.Health > 0 and Zones.contains(field, position)
	if player:GetAttribute("SnowballActive") ~= active then
		player:SetAttribute("SnowballActive", active)
	end

	local diameter = Config.diameterFromVolume(volume)
	local last = lastPositions[player]
	lastPositions[player] = position
	if active and last and humanoid.FloorMaterial ~= Enum.Material.Air then
		local step = ((position - last) * FLAT).Magnitude
		local look = root.CFrame.LookVector * FLAT
		if step >= MIN_STEP and step <= MAX_STEP and look.Magnitude > 1e-3 then
			local center = position + look.Unit * Config.ballOffset(diameter)
			local collected = SnowLayer.collect(center, Config.collectRadius(diameter))
			if collected > 0 then
				volume = math.min(volume + collected * Config.SNOW_PER_TILE, Config.volumeFromDiameter(Config.MAX_DIAMETER))
				volumes[player] = volume
				diameter = Config.diameterFromVolume(volume)
				player:SetAttribute("SnowballSize", math.floor(diameter * 100 + 0.5) / 100)
			end
		end
	end

	local walkSpeed = if active then Config.walkSpeed(diameter) else Config.BASE_WALK_SPEED
	if math.abs(humanoid.WalkSpeed - walkSpeed) > 0.05 then
		humanoid.WalkSpeed = walkSpeed
	end
end

function SnowballService.start()
	local spawnMap = Workspace:WaitForChild("Map"):WaitForChild("Spawn")
	local field = spawnMap:WaitForChild("Zones"):WaitForChild("SnowField") :: BasePart
	SnowLayer.start(spawnMap:WaitForChild("FreshSnow"))

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		volumes[player] = nil
		lastPositions[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				update(player, field)
			end
			task.wait(TICK)
		end
	end)
end

return SnowballService
