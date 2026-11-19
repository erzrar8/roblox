--!strict
-- Unlockable areas. A player has unlocked an area when the player attribute "Area_<id>" is true.
export type Area = { id: string, name: string, price: number }

local Areas = {}

Areas.ElfVillage = { id = "ElfVillage", name = "Elf Village", price = 5000 } :: Area

function Areas.attribute(id: string): string
	return "Area_" .. id
end

function Areas.unlocked(player: Player, id: string): boolean
	return player:GetAttribute(Areas.attribute(id)) == true
end

return Areas
