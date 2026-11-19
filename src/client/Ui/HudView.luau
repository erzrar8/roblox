--!strict
-- Builds the always-visible HUD: the top bar with the UPGRADES and SELL buttons, and the festive money
-- counter in the top-right corner. Layout only; Hud.luau wires up the behaviour.
local Kit = require(script.Parent.Kit)

local HudView = {}

-- Top bar, in pixels before UI scaling. UPGRADES sits at the horizontal centre of the screen with the
-- smaller SELL button to its right.
local PAD, GAP = 10, 12
local UPGRADES_SIZE = Vector2.new(210, 54)
local SELL_SIZE = Vector2.new(150, 44)
local BAR_SIZE = Vector2.new(PAD + UPGRADES_SIZE.X + GAP + SELL_SIZE.X + PAD, PAD + UPGRADES_SIZE.Y + Kit.DEPTH + PAD)
HudView.BAR_TOP = 8
HudView.BAR_SIZE = BAR_SIZE
-- Horizontal offset of the SELL button's centre from the screen centre, for effects placed under it.
HudView.SELL_OFFSET = UPGRADES_SIZE.X / 2 + GAP + SELL_SIZE.X / 2

local MONEY_SIZE = Vector2.new(236, 64)

export type Refs = {
	topBar: Frame,
	topScale: UIScale,
	upgradesButton: Kit.Button,
	sellButton: Kit.Button,
	money: Frame,
	moneyScale: UIScale,
	moneyLabel: TextLabel,
	moneyLights: Kit.Lights,
	popups: Frame,
}

function HudView.build(gui: ScreenGui): Refs
	local upgradesCenter = PAD + UPGRADES_SIZE.X / 2
	local topBar = Kit.make("Frame", {
		Name = "TopBar",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(22, 36, 62),
		BackgroundTransparency = 0.2,
		-- Anchored on the UPGRADES button's centre, so it stays centred at any UI scale.
		AnchorPoint = Vector2.new(upgradesCenter / BAR_SIZE.X, 0),
		Position = UDim2.new(0.5, 0, 0, HudView.BAR_TOP),
		Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
	}, gui)
	Kit.corner(topBar, 16)
	Kit.stroke(topBar, Kit.Colors.white, 3)
	Kit.snowCap(topBar, BAR_SIZE.X, 7)
	local topScale = Kit.make("UIScale", {}, topBar)

	local rowCenter = PAD + (UPGRADES_SIZE.Y + Kit.DEPTH) / 2
	local upgradesButton = Kit.button(topBar, {
		name = "Upgrades",
		size = UPGRADES_SIZE,
		position = UDim2.fromOffset(upgradesCenter, rowCenter),
		scheme = Kit.Schemes.green,
		text = "UPGRADES",
		maxTextSize = 26,
	})
	local sellButton = Kit.button(topBar, {
		name = "Sell",
		size = SELL_SIZE,
		position = UDim2.fromOffset(PAD + UPGRADES_SIZE.X + GAP + SELL_SIZE.X / 2, rowCenter),
		scheme = Kit.Schemes.red,
		text = "SELL",
		maxTextSize = 24,
	})

	local money = Kit.make("Frame", {
		Name = "Money",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(26, 98, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 16),
		Size = UDim2.fromOffset(MONEY_SIZE.X, MONEY_SIZE.Y),
	}, gui)
	Kit.corner(money, 14)
	Kit.stroke(money, Kit.Colors.white, 3)
	Kit.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 180)),
	}, money)
	Kit.snowCap(money, MONEY_SIZE.X, 11)
	local moneyLights = Kit.lights(money, MONEY_SIZE, 9, 14, 22)
	local moneyScale = Kit.make("UIScale", {}, money)
	Kit.icon(money, "cash", UDim2.new(0, 10, 0.5, 2), Vector2.new(58, 50), Vector2.new(0, 0.5))
	local moneyLabel = Kit.label(money, {
		name = "Amount",
		text = "0",
		position = UDim2.new(0, 76, 0.5, 2),
		anchor = Vector2.new(0, 0.5),
		size = UDim2.fromOffset(MONEY_SIZE.X - 76 - 14, 34),
		stroke = Color3.fromRGB(10, 52, 26),
		strokeThickness = 3,
		maxTextSize = 30,
		xAlign = Enum.TextXAlignment.Left,
	})

	local popups = Kit.make("Frame", {
		Name = "Popups",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, gui)

	return {
		topBar = topBar,
		topScale = topScale,
		upgradesButton = upgradesButton,
		sellButton = sellButton,
		money = money,
		moneyScale = moneyScale,
		moneyLabel = moneyLabel,
		moneyLights = moneyLights,
		popups = popups,
	}
end

return HudView
