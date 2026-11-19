--!strict
local Zones = {}

-- True when `position` is inside the (possibly rotated) box of `zone`.
function Zones.contains(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

return Zones
