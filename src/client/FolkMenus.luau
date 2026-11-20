--!strict
-- Folk Stud UI menus (kit: Ui/FolkStudUI): a rail on the left opens Upgrades, Elf Tasks and Settings.
-- Built at runtime into PlayerGui; every window starts closed. The server checks and pays for
-- everything (EconomyService, MissionService); these windows only show its numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Missions = require(Shared:WaitForChild("Missions"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local ClientSettings = require(script.Parent.ClientSettings)
local Folk = require(script.Parent.Ui.FolkStudUI) :: any

local COLOR, ART = Folk.COLOR, Folk.ART

-- Icons are the kit's placeholder art: swap these image ids for the game's own icons.
local ICONS = {
	upgrades = ART.arrow,
	tasks = ART.quest,
	settings = ART.star,
	reward = ART.gift,
	elf = ART.star,
	SnowPower = ART.star,
	BallCapacity = ART.arrow,
	SpeedBoost = ART.arrow,
	CashMultiplier = ART.gift,
}
local UPGRADE_COLORS = {
	SnowPower = COLOR.blue,
	BallCapacity = COLOR.purple,
	SpeedBoost = COLOR.orange,
	CashMultiplier = COLOR.green,
}
local UPGRADE_SECTIONS = {
	{ name = "Snowball", color = COLOR.blue, ids = { "SnowPower", "BallCapacity" } },
	{ name = "Player", color = COLOR.orange, ids = { "SpeedBoost", "CashMultiplier" } },
}
local ELF_COLORS = { Jingle = COLOR.crimson, Tinsel = COLOR.blue, Sprinkles = COLOR.pink }
local DONE_HOLD = 1.2 -- seconds a claimed task shows DONE! before the elf's next task

local FolkMenus = {}

local screens: { [string]: ScreenGui } = {}

-- Opens a window by its ScreenGui name (closing any other), or closes it if it is open.
function FolkMenus.toggle(name: string)
	local target = screens[name]
	if not target then
		return
	end
	local opening = not target.Enabled
	for other, gui in screens do
		if other ~= name and gui.Enabled then
			Folk.show(gui, false)
		end
	end
	Folk.show(target, opening)
end

local function shake(button: GuiObject)
	task.spawn(function()
		for _, rotation in { -7, 7, -5, 5, -2, 0 } do
			button.Rotation = rotation
			task.wait(0.035)
		end
	end)
end

local function money(player: Player): number
	local value = player:GetAttribute("Money")
	return if typeof(value) == "number" then value else 0
end

local function number(player: Player, attribute: string, default: number): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else default
end

local function rowOf(gui: ScreenGui, name: string): Instance?
	return (gui :: any).Root.Stage.Window.Scroll.Content:FindFirstChild(name)
end

------------------------------------------------------------------ upgrades
local function upgradeState(player: Player, definition: Upgrades.Definition)
	local level = Upgrades.level(player, definition.id)
	local cost = Upgrades.cost(definition.id, level)
	return {
		level = level,
		max = definition.maxLevel,
		now = definition.format(Upgrades.value(definition.id, level)),
		nextValue = definition.format(Upgrades.value(definition.id, level + 1)),
		price = "$" .. Format.short(cost),
		affordable = money(player) >= cost,
	}
end

local function buildUpgrades(player: Player, parent: Instance, buyRemote: RemoteFunction): ScreenGui
	local sections = {}
	for _, section in UPGRADE_SECTIONS do
		local list = {}
		for _, id in section.ids do
			local definition = Upgrades.byId[id]
			table.insert(list, {
				id = id,
				title = definition.name,
				icon = ICONS[id],
				color = UPGRADE_COLORS[id],
				state = upgradeState(player, definition),
			})
		end
		table.insert(sections, { name = section.name, color = section.color, icon = ICONS[section.ids[1]], upgrades = list })
	end
	local gui = Folk.upgrades(nil, { title = "Upgrades", icon = ICONS.upgrades, sections = sections })

	local function refresh(bumpId: string?)
		for _, definition in Upgrades.list do
			Folk.setUpgrade(gui, definition.id, upgradeState(player, definition), definition.id == bumpId)
		end
	end
	player:GetAttributeChangedSignal("Money"):Connect(function()
		refresh()
	end)
	for _, definition in Upgrades.list do
		player:GetAttributeChangedSignal(Upgrades.attribute(definition.id)):Connect(function()
			refresh(definition.id)
		end)
	end

	gui.Enabled = false
	gui.Parent = parent
	Folk.live(gui, {
		buy = function(id: string)
			local definition = Upgrades.byId[id]
			local row = rowOf(gui, "Upgrade" .. id)
			local button = if row then row:FindFirstChild("Buy") :: GuiObject? else nil
			if not definition or not button then
				return
			end
			local level = Upgrades.level(player, id)
			if level >= definition.maxLevel or money(player) < Upgrades.cost(id, level) then
				shake(button)
				return
			end
			local result = buyRemote:InvokeServer(id)
			if typeof(result) ~= "table" or not result.ok then
				shake(button)
			end
		end,
	})
	return gui
end

------------------------------------------------------------------ elf tasks
local function buildTasks(player: Player, parent: Instance, claimRemote: RemoteFunction): ScreenGui
	local quests = {}
	for _, elf in Missions.elves do
		table.insert(quests, {
			id = elf.id,
			title = elf.name,
			desc = "",
			have = 0,
			need = 1,
			reward = "",
			rewardIcon = ICONS.reward,
			color = ELF_COLORS[elf.id],
			icon = ICONS.elf,
		})
	end
	local gui = Folk.quests(nil, {
		title = "Elf Tasks",
		icon = ICONS.tasks,
		sections = { { name = "Elf Village", icon = ICONS.tasks, color = COLOR.green, quests = quests } },
	})

	local holdUntil: { [string]: number } = {}
	local function refresh()
		local active = Missions.activeElf(player)
		for _, elf in Missions.elves do
			local row = rowOf(gui, "Quest" .. elf.id) :: any
			if row and os.clock() >= (holdUntil[elf.id] or 0) then
				local have, need, reward, text, title
				if active == elf.id then
					need = math.max(number(player, "MissionGoal", 1), 1)
					have = math.min(number(player, "MissionProgress", 0), need)
					reward = number(player, "MissionReward", 0)
					local missionText = player:GetAttribute("MissionText")
					text = if typeof(missionText) == "string" then missionText else ""
					title = elf.name
				else
					local nextTask = Missions.task(elf.id, Missions.level(player, elf.id))
					have, need, reward, text = 0, nextTask.goal, nextTask.reward, nextTask.text
					title = "Talk to " .. elf.name
				end
				row:SetAttribute("Hero", active == elf.id)
				Folk.setQuest(gui, elf.id, have, need, if active == elf.id and have >= need then "ready" else "go")
				row.Count.Text = `{Format.short(have)}/{Format.short(need)}`
				row.Title.Text = title
				row.Desc.Text = text
				row.Reward.Text = "+" .. Format.short(reward)
			end
		end
	end
	for _, attribute in { "MissionElf", "MissionText", "MissionGoal", "MissionProgress", "MissionReward" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	for _, elf in Missions.elves do
		player:GetAttributeChangedSignal("ElfLevel_" .. elf.id):Connect(refresh)
	end
	refresh()

	gui.Enabled = false
	gui.Parent = parent
	Folk.live(gui, {
		-- GO: the task is done out in the world, so just get out of the way.
		go = function()
			Folk.show(gui, false)
		end,
		claim = function(id: string)
			-- Hold the row before asking: the server clears the task attributes before its answer arrives.
			local need = math.max(number(player, "MissionGoal", 1), 1)
			holdUntil[id] = os.clock() + DONE_HOLD
			local result = claimRemote:InvokeServer(id)
			if typeof(result) == "table" and result.ok then
				Folk.setQuest(gui, id, need, need, "done")
				local row = rowOf(gui, "Quest" .. id) :: any
				if row then
					row.Count.Text = `{Format.short(need)}/{Format.short(need)}`
				end
				task.delay(DONE_HOLD + 0.05, refresh)
			else
				holdUntil[id] = nil
				refresh()
			end
		end,
	})
	return gui
end

------------------------------------------------------------------ settings
local function buildSettings(parent: Instance): ScreenGui
	local gui = Folk.settings(nil, {
		title = "Settings",
		icon = ICONS.settings,
		sections = {
			{
				name = "Gameplay",
				color = COLOR.blue,
				icon = ICONS.settings,
				rows = {
					{ id = "Snowfall", title = "Falling Snow", desc = "Snowflakes around you", value = ClientSettings.get("Snowfall"), color = COLOR.blue, icon = ICONS.settings },
					{ id = "TaskTracker", title = "Task Tracker", desc = "Elf task box under your money", value = ClientSettings.get("TaskTracker"), color = COLOR.green, icon = ICONS.tasks },
				},
			},
		},
	})
	gui.Enabled = false
	gui.Parent = parent
	Folk.settingsLive(gui, {
		change = function(id: ClientSettings.Id, value: boolean)
			ClientSettings.set(id, value)
		end,
	})
	return gui
end

function FolkMenus.start()
	local player = Players.LocalPlayer :: Player
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
	local claimRemote = remotes:WaitForChild("ClaimMission") :: RemoteFunction

	screens.FolkUpgrades = buildUpgrades(player, playerGui, buyRemote)
	screens.FolkQuests = buildTasks(player, playerGui, claimRemote)
	screens.FolkSettings = buildSettings(playerGui)

	local rail = Folk.hud(playerGui, {
		buttons = {
			{ label = "Upgrades", icon = ICONS.upgrades, color = COLOR.hudShop, opens = "FolkUpgrades" },
			{ label = "Tasks", icon = ICONS.tasks, color = COLOR.hudPurple, opens = "FolkQuests" },
			{ label = "Settings", icon = ICONS.settings, color = COLOR.hudBlue, opens = "FolkSettings" },
		},
	})
	Folk.live(rail, { open = FolkMenus.toggle })
end

return FolkMenus
