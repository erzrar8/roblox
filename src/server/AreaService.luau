--!strict
-- Locked areas. The Zone 1 gate gets an "Unlock" prompt; paying unlocks the Elf Village for that
-- player (attribute Area_ElfVillage), after which their client drops the gate's barrier locally
-- (src/client/AreaGate.luau). Players who get past the gate without unlocking are sent back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared:WaitForChild("Areas"))
local Format = require(Shared:WaitForChild("Format"))
local EconomyService = require(script.Parent.EconomyService)

local CHECK_INTERVAL = 0.5

local AreaService = {}

function AreaService.start()
	local area = Areas.ElfVillage
	local spawnMap = Workspace:WaitForChild("Map"):WaitForChild("Spawn")
	local gate = spawnMap:WaitForChild("Zone1Gate")
	local barrier = gate:WaitForChild("ZoneBarrier") :: BasePart
	local spot = gate:WaitForChild("UnlockSpot") :: BasePart
	local gateZ = barrier.Position.Z
	-- Where locked-out players are put back: in front of the gate, facing it.
	local returnTo = CFrame.lookAt(Vector3.new(0, barrier.Position.Y - barrier.Size.Y / 2 + 3, gateZ + 10), Vector3.new(0, 3, gateZ))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = `Unlock ({Format.short(area.price)})`
	prompt.ObjectText = area.name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot

	prompt.Triggered:Connect(function(player)
		if Areas.unlocked(player, area.id) then
			return
		end
		if EconomyService.trySpend(player, area.price) then
			player:SetAttribute(Areas.attribute(area.id), true)
			EconomyService.notify(player, `{string.upper(area.name)} UNLOCKED!`, "good")
		else
			local missing = area.price - EconomyService.money(player)
			EconomyService.notify(player, `NEED {Format.short(missing)} MORE!`, "bad")
		end
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if not Areas.unlocked(player, area.id) then
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if character and root and root.Position.Z < gateZ - 1 then
						character:PivotTo(returnTo)
						EconomyService.notify(player, `UNLOCK THE {string.upper(area.name)} FIRST!`, "bad")
					end
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return AreaService
