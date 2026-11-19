--!strict
-- HUD behaviour: UPGRADES opens the upgrades window, SELL sells the snowball, and the money counter
-- counts up with a twinkling string of Christmas lights. The server does all the maths
-- (EconomyService); this only shows its results.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local Missions = require(Shared:WaitForChild("Missions"))
local Kit = require(script.Parent.Ui.Kit)
local HudView = require(script.Parent.Ui.HudView)
local UpgradesView = require(script.Parent.Ui.UpgradesView)
local MissionView = require(script.Parent.Ui.MissionView)

local DESIGN_SIZE = Vector2.new(1100, 640) -- below this viewport size the HUD scales down
local MIN_SCALE = 0.55
local BLINK_INTERVAL = 0.6
local POPUP_COLORS = {
	gain = Color3.fromRGB(255, 220, 70),
	gainEdge = Color3.fromRGB(110, 70, 0),
	error = Color3.fromRGB(255, 110, 110),
	errorEdge = Color3.fromRGB(90, 8, 14),
	info = Color3.fromRGB(255, 255, 255),
	infoEdge = Color3.fromRGB(22, 52, 104),
}

local Hud = {}

local function tween(instance: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, info, props):Play()
end

local function bindPress(button: Kit.Button, onActivated: () -> ())
	local target = button.button
	target.MouseEnter:Connect(function()
		tween(button.scale, 0.12, { Scale = 1.06 })
	end)
	target.MouseLeave:Connect(function()
		tween(button.scale, 0.12, { Scale = 1 })
	end)
	target.MouseButton1Down:Connect(function()
		tween(button.scale, 0.08, { Scale = 0.92 })
	end)
	target.MouseButton1Up:Connect(function()
		tween(button.scale, 0.12, { Scale = 1.06 })
	end)
	target.Activated:Connect(onActivated)
end

local function shake(button: Kit.Button)
	task.spawn(function()
		for _, rotation in { -7, 7, -5, 5, -2, 0 } do
			button.button.Rotation = rotation
			task.wait(0.035)
		end
	end)
end

local function popup(container: Frame, text: string, position: UDim2, color: Color3, edge: Color3)
	local label = Kit.label(container, {
		name = "Popup",
		text = text,
		position = position,
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.fromOffset(260, 34),
		color = color,
		stroke = edge,
		strokeThickness = 3,
		maxTextSize = 28,
		zIndex = 20,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = position - UDim2.fromOffset(0, 46), TextTransparency = 1 }):Play()
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
	task.delay(1.2, function()
		label:Destroy()
	end)
end

local function blink(lights: Kit.Lights, phase: number)
	for index, bulb in lights.bulbs do
		local color = lights.colors[index]
		bulb.BackgroundColor3 = if (index + phase) % 2 == 0 then color else color:Lerp(Color3.new(0, 0, 0), 0.55)
	end
end

function Hud.start()
	local player = Players.LocalPlayer :: Player
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local sellRemote = remotes:WaitForChild("Sell") :: RemoteFunction
	local buyRemote = remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
	local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

	-- The default player list sits in the top-right corner, right where the money counter goes.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	local gui = Kit.make("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	local hud = HudView.build(gui)
	local specs: { UpgradesView.Spec } = {}
	for _, definition in Upgrades.list do
		table.insert(specs, { id = definition.id, name = definition.name, icon = definition.icon })
	end
	local window = UpgradesView.build(gui, specs)
	local tracker = MissionView.build(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Scale everything down on small screens.
	local hudScale, windowScale = HudView.SCALE, UpgradesView.SCALE
	local function rescale()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else DESIGN_SIZE
		local screen = math.clamp(math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y), MIN_SCALE, 1)
		hudScale, windowScale = HudView.SCALE * screen, UpgradesView.SCALE * screen
		hud.topScale.Scale = hudScale
		hud.moneyScale.Scale = hudScale
		tracker.scale.Scale = hudScale
		window.scale.Scale = windowScale
	end
	rescale()
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
		rescale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	-- Money counter: counts up to the new balance and gives a little bounce.
	local shownMoney = Instance.new("NumberValue")
	local function money(): number
		local value = player:GetAttribute("Money")
		return if typeof(value) == "number" then value else 0
	end
	shownMoney.Value = money()
	hud.moneyLabel.Text = Format.short(shownMoney.Value)
	shownMoney.Changed:Connect(function(value)
		hud.moneyLabel.Text = Format.short(value)
	end)

	-- Upgrades window rows.
	local function refreshRows()
		local balance = money()
		for _, definition in Upgrades.list do
			local level = Upgrades.level(player, definition.id)
			local cost = Upgrades.cost(definition.id, level)
			UpgradesView.setRow(window.rows[definition.id], {
				current = "Now: " .. definition.format(Upgrades.value(definition.id, level)),
				price = Format.short(cost),
				level = tostring(level),
				affordable = balance >= cost,
				maxed = level >= definition.maxLevel,
			})
		end
	end
	refreshRows()

	player:GetAttributeChangedSignal("Money"):Connect(function()
		local target = money()
		local gained = target > shownMoney.Value
		tween(shownMoney, 0.5, { Value = target })
		if gained then
			tween(hud.moneyScale, 0.1, { Scale = hudScale * 1.12 })
			task.delay(0.12, function()
				tween(hud.moneyScale, 0.25, { Scale = hudScale }, Enum.EasingStyle.Back)
			end)
		end
		refreshRows()
	end)

	for _, definition in Upgrades.list do
		local row = window.rows[definition.id]
		player:GetAttributeChangedSignal(Upgrades.attribute(definition.id)):Connect(function()
			refreshRows()
			tween(row.levelBox.scale, 0.1, { Scale = 1.2 })
			task.delay(0.12, function()
				tween(row.levelBox.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end)
		bindPress(row.upgrade, function()
			local level = Upgrades.level(player, definition.id)
			if level >= definition.maxLevel or money() < Upgrades.cost(definition.id, level) then
				shake(row.upgrade)
				return
			end
			local result = buyRemote:InvokeServer(definition.id)
			if typeof(result) ~= "table" or not result.ok then
				shake(row.upgrade)
			end
		end)
	end

	-- Opening and closing the upgrades window.
	local open = false
	local function setOpen(value: boolean)
		if open == value then
			return
		end
		open = value
		if value then
			refreshRows()
			window.root.Visible = true
			window.scale.Scale = windowScale * 0.8
			tween(window.scale, 0.25, { Scale = windowScale }, Enum.EasingStyle.Back)
		else
			tween(window.scale, 0.12, { Scale = windowScale * 0.8 })
			task.delay(0.12, function()
				if not open then
					window.root.Visible = false
				end
			end)
		end
	end
	bindPress(hud.upgradesButton, function()
		setOpen(not open)
	end)
	bindPress(window.close, function()
		setOpen(false)
	end)

	-- Selling.
	bindPress(hud.sellButton, function()
		local result = sellRemote:InvokeServer()
		if typeof(result) == "table" and result.ok and typeof(result.amount) == "number" then
			popup(hud.popups, "+" .. Format.short(result.amount), UDim2.new(1, -110 * hudScale, 0, 120 * hudScale), POPUP_COLORS.gain, POPUP_COLORS.gainEdge)
		elseif typeof(result) == "table" and result.reason == "empty" then
			shake(hud.sellButton)
			local below = (HudView.BAR_TOP + HudView.BAR_SIZE.Y + 22) * hudScale
			popup(hud.popups, "NO SNOW YET!", UDim2.new(0.5, HudView.SELL_OFFSET * hudScale, 0, below), POPUP_COLORS.error, POPUP_COLORS.errorEdge)
		end
	end)

	-- Messages from the server (unlocks, elf tasks), shown big in the middle of the screen. A new one
	-- replaces the one on screen.
	local current: TextLabel? = nil
	notifyRemote.OnClientEvent:Connect(function(text: unknown, kind: unknown)
		if typeof(text) ~= "string" then
			return
		end
		if current then
			current:Destroy()
		end
		local color, edge = POPUP_COLORS.info, POPUP_COLORS.infoEdge
		if kind == "good" then
			color, edge = POPUP_COLORS.gain, POPUP_COLORS.gainEdge
		elseif kind == "bad" then
			color, edge = POPUP_COLORS.error, POPUP_COLORS.errorEdge
		end
		local label = Kit.label(hud.popups, {
			name = "Toast",
			text = text,
			position = UDim2.fromScale(0.5, 0.3),
			anchor = Vector2.new(0.5, 0.5),
			size = UDim2.new(0.9, 0, 0, 40),
			color = color,
			stroke = edge,
			strokeThickness = 3,
			maxTextSize = math.floor(30 * hudScale / HudView.SCALE),
			zIndex = 21,
		})
		current = label
		local scale = Kit.make("UIScale", { Scale = 0.6 }, label)
		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(2.2, function()
			if label.Parent then
				local stroke = label:FindFirstChildOfClass("UIStroke")
				tween(label, 0.4, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.3, -24) })
				if stroke then
					tween(stroke, 0.4, { Transparency = 1 })
				end
				task.delay(0.45, function()
					label:Destroy()
				end)
			end
		end)
	end)

	-- Elf task tracker.
	local trackerShown = false
	local function refreshTracker()
		local elfId = Missions.activeElf(player)
		if not elfId then
			if trackerShown then
				trackerShown = false
				tween(tracker.scale, 0.15, { Scale = 0 })
				task.delay(0.16, function()
					if not trackerShown then
						tracker.root.Visible = false
					end
				end)
			end
			return
		end
		local goal, progress = player:GetAttribute("MissionGoal"), player:GetAttribute("MissionProgress")
		local text = player:GetAttribute("MissionText")
		local g = if typeof(goal) == "number" then goal else 1
		local p = if typeof(progress) == "number" then progress else 0
		local elf = Missions.byId[elfId]
		MissionView.set(tracker, {
			elf = if elf then elf.name else elfId,
			text = if typeof(text) == "string" then text else "",
			progress = p / math.max(g, 1),
			count = if g > 1 then `{Format.short(p)}/{Format.short(g)}` else `{p}/{g}`,
			done = p >= g,
		})
		if not trackerShown then
			trackerShown = true
			tracker.root.Visible = true
			tracker.scale.Scale = 0
			tween(tracker.scale, 0.3, { Scale = hudScale }, Enum.EasingStyle.Back)
		end
	end
	for _, attribute in { "MissionElf", "MissionText", "MissionGoal", "MissionProgress" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshTracker)
	end
	refreshTracker()

	-- Twinkling lights.
	task.spawn(function()
		local phase = 0
		while true do
			blink(hud.moneyLights, phase)
			if open then
				blink(window.lights, phase)
			end
			phase = 1 - phase
			task.wait(BLINK_INTERVAL)
		end
	end)
end

return Hud
