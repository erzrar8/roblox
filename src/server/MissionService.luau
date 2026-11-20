--!strict
-- Elf missions (definitions in Shared.Missions). Each elf in the Elf Village gets a "Talk" prompt:
-- talking with no task in progress takes that elf's next task, talking to the same elf again with the
-- task done hands it in for the reward (or CLAIM in the Elf Tasks window). Progress comes from SnowballService (candy snow collected)
-- and EconomyService (sales).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Missions = require(Shared:WaitForChild("Missions"))
local EconomyService = require(script.Parent.EconomyService)
local SnowballService = require(script.Parent.SnowballService)

local CANDY_FIELD = "CandyField"

local MissionService = {}

local function clear(player: Player)
	for _, attribute in { "MissionElf", "MissionText", "MissionGoal", "MissionProgress", "MissionReward", "MissionParam" } do
		player:SetAttribute(attribute, nil)
	end
end

local function give(player: Player, elf: Missions.Elf)
	local task = Missions.task(elf.id, Missions.level(player, elf.id))
	player:SetAttribute("MissionElf", elf.id)
	player:SetAttribute("MissionText", task.text)
	player:SetAttribute("MissionGoal", task.goal)
	player:SetAttribute("MissionProgress", 0)
	player:SetAttribute("MissionReward", task.reward)
	player:SetAttribute("MissionParam", task.param)
	EconomyService.notify(player, `{string.upper(elf.name)}: {string.upper(task.text)}!`, "info")
end

local function progress(player: Player, kind: Missions.Kind, amount: number)
	local elfId = Missions.activeElf(player)
	if not elfId or Missions.byId[elfId].kind ~= kind or Missions.isDone(player) then
		return
	end
	local goal = player:GetAttribute("MissionGoal") :: number
	local current = player:GetAttribute("MissionProgress") :: number
	local value = math.min(current + amount, goal)
	player:SetAttribute("MissionProgress", value)
	if value >= goal then
		EconomyService.notify(player, `TASK DONE! RETURN TO {string.upper(Missions.byId[elfId].name)}`, "good")
	end
end

local function handIn(player: Player, elf: Missions.Elf)
	local reward = player:GetAttribute("MissionReward")
	local amount = if typeof(reward) == "number" then reward else 0
	EconomyService.addMoney(player, amount)
	player:SetAttribute("ElfLevel_" .. elf.id, Missions.level(player, elf.id) + 1)
	clear(player)
	EconomyService.notify(player, `THANKS! +{Format.short(amount)}`, "good")
end

local function talk(player: Player, elf: Missions.Elf)
	local active = Missions.activeElf(player)
	if not active then
		give(player, elf)
	elseif active ~= elf.id then
		EconomyService.notify(player, `FINISH {string.upper(Missions.byId[active].name)}'S TASK FIRST!`, "bad")
	elseif Missions.isDone(player) then
		handIn(player, elf)
	else
		local goal, current = player:GetAttribute("MissionGoal"), player:GetAttribute("MissionProgress")
		EconomyService.notify(player, `KEEP GOING! {current}/{goal}`, "info")
	end
end

-- CLAIM in the Elf Tasks window: hands in the player's finished task without walking back.
local function claim(player: Player, elfId: unknown): { ok: boolean }
	local elf = if typeof(elfId) == "string" then Missions.byId[elfId] else nil
	if not elf or Missions.activeElf(player) ~= elf.id or not Missions.isDone(player) then
		return { ok = false }
	end
	handIn(player, elf)
	return { ok = true }
end

function MissionService.start()
	local claimRemote = Instance.new("RemoteFunction")
	claimRemote.Name = "ClaimMission"
	claimRemote.OnServerInvoke = claim
	claimRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	local elves = Workspace:WaitForChild("Map"):WaitForChild("Spawn"):WaitForChild("Village"):WaitForChild("Elves")
	for _, model in elves:GetChildren() do
		local id = model:GetAttribute("ElfId")
		local elf = if typeof(id) == "string" then Missions.byId[id] else nil
		local spot = model:FindFirstChild("TalkSpot")
		if elf and spot then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TalkPrompt"
			prompt.ActionText = "Talk"
			prompt.ObjectText = elf.name
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt.Parent = spot
			prompt.Triggered:Connect(function(player)
				talk(player, elf)
			end)
		end
	end

	SnowballService.onCollected(function(player, field, tiles)
		if field == CANDY_FIELD then
			progress(player, "candy", tiles)
		end
	end)
	EconomyService.onSold(function(player, diameter, amount)
		progress(player, "earn", amount)
		local param = player:GetAttribute("MissionParam")
		if typeof(param) == "number" and diameter + 0.01 >= param then
			progress(player, "bigball", 1)
		end
	end)

	Players.PlayerRemoving:Connect(clear)
end

return MissionService
