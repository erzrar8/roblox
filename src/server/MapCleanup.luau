--!strict
-- The map lives in Workspace.Map (synced by Rojo). Places opened before that change can still hold an
-- old copy of the island at Workspace.Spawn, or a template SpawnLocation; both would make players
-- spawn in the wrong place, so they are removed when the server starts.
local Workspace = game:GetService("Workspace")

local MapCleanup = {}

function MapCleanup.run()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn("MapCleanup: Workspace.Map is missing, skipping cleanup")
		return
	end

	local legacy = Workspace:FindFirstChild("Spawn")
	if legacy then
		legacy:Destroy()
	end

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and not descendant:IsDescendantOf(map) then
			descendant:Destroy()
		end
	end
end

return MapCleanup
