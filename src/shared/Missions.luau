--!strict
-- Elf missions in the Elf Village. Each elf gives one kind of task that gets harder (and pays more)
-- every time it is completed. A player works on one task at a time; its state lives in player
-- attributes set by the server (MissionService):
--   MissionElf (elf id), MissionText, MissionGoal, MissionProgress, MissionReward, MissionParam,
--   ElfLevel_<elf id> (tasks completed for that elf).
local Format = require(script.Parent.Format)

export type Kind = "candy" | "bigball" | "earn"
export type Elf = { id: string, name: string, kind: Kind }
export type Task = { goal: number, reward: number, param: number, text: string }

local Missions = {}

Missions.elves = {
	{ id = "Jingle", name = "Jingle", kind = "candy" },
	{ id = "Tinsel", name = "Tinsel", kind = "bigball" },
	{ id = "Sprinkles", name = "Sprinkles", kind = "earn" },
} :: { Elf }

Missions.byId = {} :: { [string]: Elf }
for _, elf in Missions.elves do
	Missions.byId[elf.id] = elf
end

local MAX_BALL = 100

-- The task an elf gives at `level` (how many of its tasks the player has finished).
function Missions.task(elfId: string, level: number): Task
	local kind = Missions.byId[elfId].kind
	if kind == "candy" then
		local goal = math.floor(60 * 1.5 ^ level + 0.5)
		return { goal = goal, reward = math.floor(400 * 1.6 ^ level + 0.5), param = 0, text = `Collect {goal} candy snow` }
	elseif kind == "bigball" then
		local size = math.min(10 + 3 * level, MAX_BALL)
		return { goal = 1, reward = math.floor(500 * 1.6 ^ level + 0.5), param = size, text = `Sell a {size}-stud ball` }
	end
	local goal = math.floor(1500 * 1.8 ^ level + 0.5)
	return { goal = goal, reward = math.floor(goal * 0.3 + 0.5), param = 0, text = `Earn {Format.short(goal)} from sales` }
end

function Missions.level(player: Player, elfId: string): number
	local level = player:GetAttribute("ElfLevel_" .. elfId)
	return if typeof(level) == "number" then level else 0
end

-- Id of the elf whose task the player is doing, if any.
function Missions.activeElf(player: Player): string?
	local elf = player:GetAttribute("MissionElf")
	return if typeof(elf) == "string" and elf ~= "" then elf else nil
end

function Missions.isDone(player: Player): boolean
	local goal, progress = player:GetAttribute("MissionGoal"), player:GetAttribute("MissionProgress")
	return typeof(goal) == "number" and typeof(progress) == "number" and progress >= goal
end

return Missions
