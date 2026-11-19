--!strict
-- The Zone 1 gate's barrier is solid on the server. Once this player has unlocked the Elf Village,
-- the barrier is switched off on this client only (the character's physics run here), and the unlock
-- prompt is hidden. AreaService still sends back anyone who slips past without unlocking.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Areas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Areas"))

local AreaGate = {}

function AreaGate.start()
	local player = Players.LocalPlayer :: Player
	local gate = Workspace:WaitForChild("Map"):WaitForChild("Spawn"):WaitForChild("Zone1Gate")
	local area = gate:GetAttribute("Area")
	if typeof(area) ~= "string" then
		return
	end
	local barrier = gate:WaitForChild("ZoneBarrier") :: BasePart
	local spot = gate:WaitForChild("UnlockSpot")
	local lockedTransparency = barrier.Transparency

	local function refresh()
		local unlocked = Areas.unlocked(player, area)
		barrier.CanCollide = not unlocked
		barrier.Transparency = if unlocked then 1 else lockedTransparency
		local prompt = spot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not unlocked
		end
	end

	player:GetAttributeChangedSignal(Areas.attribute(area)):Connect(refresh)
	spot.ChildAdded:Connect(refresh)
	refresh()
end

return AreaGate
