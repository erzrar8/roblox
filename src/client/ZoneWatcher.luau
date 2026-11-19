--!strict
-- Tracks which zone volume (a part with a "ZoneName" attribute) the local character stands in and
-- shows the zone banner whenever the player reaches a different zone than the last one shown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zones = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Zones"))
local ZoneBanner = require(script.Parent.ZoneBanner)

local CHECK_INTERVAL = 0.2

local ZoneWatcher = {}

local zones: { [BasePart]: true } = {}

local function track(instance: Instance)
	if instance:IsA("BasePart") and instance:GetAttribute("ZoneName") ~= nil then
		zones[instance] = true
	end
end

local contains = Zones.contains

-- Smallest volume wins, so a zone nested inside a bigger one takes priority.
local function zoneAt(position: Vector3): BasePart?
	local best: BasePart?, bestVolume = nil, math.huge
	for zone in zones do
		if zone.Parent and contains(zone, position) then
			local volume = zone.Size.X * zone.Size.Y * zone.Size.Z
			if volume < bestVolume then
				best, bestVolume = zone, volume
			end
		end
	end
	return best
end

function ZoneWatcher.start()
	for _, descendant in Workspace:GetDescendants() do
		track(descendant)
	end
	Workspace.DescendantAdded:Connect(track)
	Workspace.DescendantRemoving:Connect(function(instance)
		zones[instance :: BasePart] = nil
	end)

	local player = Players.LocalPlayer
	local lastShown: BasePart? = nil
	task.spawn(function()
		while true do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local zone = zoneAt(rootPart.Position)
				if zone and zone ~= lastShown then
					lastShown = zone
					ZoneBanner.show(zone:GetAttribute("ZoneName") :: string, zone:GetAttribute("ZoneSubtitle") :: string?)
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return ZoneWatcher
