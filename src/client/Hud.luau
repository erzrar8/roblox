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
local Kit = require(script.Parent.Ui.Kit)
local HudView = require(script.Parent.Ui.HudView)
local UpgradesView = require(script.Parent.Ui.UpgradesView)

local DESIGN_SIZE = Vector2.new(1100, 640) -- below this viewport size the HUD scales down
local MIN_SCALE = 0.55
local BLINK_INTERVAL = 0.6
local POPUP_COLORS = {
	gain = Color3.fromRGB(255, 220, 70),
	gainEdge = Color3.fromRGB(110, 70, 0),
	error = Color3.fromRGB(255, 110, 110),
	errorEdge = Color3.fromRGB(90, 8, 14),
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
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Scale everything down on small screens.
	local screenScale = 1
	local function rescale()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else DESIGN_SIZE
		screenScale = math.clamp(math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y), MIN_SCALE, 1)
		hud.topScale.Scale = screenScale
		hud.moneyScale.Scale = screenScale
		window.scale.Scale = screenScale
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
			tween(hud.moneyScale, 0.1, { Scale = screenScale * 1.12 })
			task.delay(0.12, function()
				tween(hud.moneyScale, 0.25, { Scale = screenScale }, Enum.EasingStyle.Back)
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
			window.scale.Scale = screenScale * 0.8
			tween(window.scale, 0.25, { Scale = screenScale }, Enum.EasingStyle.Back)
		else
			tween(window.scale, 0.12, { Scale = screenScale * 0.8 })
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
			popup(hud.popups, "+" .. Format.short(result.amount), UDim2.new(1, -140 * screenScale, 0, 110 * screenScale), POPUP_COLORS.gain, POPUP_COLORS.gainEdge)
		elseif typeof(result) == "table" and result.reason == "empty" then
			shake(hud.sellButton)
			local below = (HudView.BAR_TOP + HudView.BAR_SIZE.Y + 22) * screenScale
			popup(hud.popups, "NO SNOW YET!", UDim2.new(0.5, HudView.SELL_OFFSET * screenScale, 0, below), POPUP_COLORS.error, POPUP_COLORS.errorEdge)
		end
	end)

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
