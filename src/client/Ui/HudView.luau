--!strict
-- Builds the always-visible HUD: the SELL button at the top centre and the festive money counter in the
-- top-right corner (upgrades open from the Folk rail on the left). Layout only; Hud.luau wires up the behaviour.
local Kit = require(script.Parent.Kit)

local HudView = {}

-- In pixels before UI scaling, with no panel behind it.
local SELL_SIZE = Vector2.new(180, 52)
local BAR_SIZE = Vector2.new(SELL_SIZE.X, SELL_SIZE.Y + Kit.DEPTH)
HudView.BAR_TOP = 10
-- The whole HUD is drawn at this size (times the small-screen factor).
HudView.SCALE = 0.8
HudView.BAR_SIZE = BAR_SIZE
-- Horizontal offset of the SELL button's centre from the screen centre, for effects placed under it.
HudView.SELL_OFFSET = 0

local MONEY_SIZE = Vector2.new(236, 64)

export type Refs = {
	topBar: Frame,
	topScale: UIScale,
	sellButton: Kit.Button,
	money: Frame,
	moneyScale: UIScale,
	moneyLabel: TextLabel,
	moneyLights: Kit.Lights,
	popups: Frame,
}

function HudView.build(gui: ScreenGui): Refs
	local topBar = Kit.make("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, HudView.BAR_TOP),
		Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
	}, gui)
	local topScale = Kit.make("UIScale", {}, topBar)

	local sellButton = Kit.button(topBar, {
		name = "Sell",
		size = SELL_SIZE,
		position = UDim2.fromOffset(SELL_SIZE.X / 2, BAR_SIZE.Y / 2),
		scheme = Kit.Schemes.red,
		text = "SELL",
		maxTextSize = 28,
	})

	local money = Kit.make("Frame", {
		Name = "Money",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(26, 98, 56),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(MONEY_SIZE.X, MONEY_SIZE.Y),
	}, gui)
	Kit.corner(money, 14)
	Kit.stroke(money, Kit.Colors.white, 3)
	Kit.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 180)),
	}, money)
	Kit.snowCap(money, MONEY_SIZE.X, 11)
	-- The wire runs along the white border (3 px), with the bulbs hanging just outside it.
	local moneyLights = Kit.lights(money, MONEY_SIZE, 1, 14, 22)
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
		sellButton = sellButton,
		money = money,
		moneyScale = moneyScale,
		moneyLabel = moneyLabel,
		moneyLights = moneyLights,
		popups = popups,
	}
end

return HudView
