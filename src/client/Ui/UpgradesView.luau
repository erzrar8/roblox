--!strict
-- Builds the Christmas-themed upgrades window: a red panel framed by Christmas lights, a studded green
-- header with a close button, and one row per upgrade with its icon, current effect, price and level.
-- Layout only; Hud.luau wires up the behaviour.
local Kit = require(script.Parent.Kit)

local UpgradesView = {}

local WIDTH = 480
local HEADER_HEIGHT = 60
local ROW_HEIGHT, ROW_GAP, ROWS_TOP = 78, 8, 84
local ROW_WIDTH = WIDTH - 24

local COLORS = {
	panel = Color3.fromRGB(124, 22, 32),
	shadow = Color3.fromRGB(46, 6, 12),
	row = Color3.fromRGB(88, 14, 22),
	rowEdge = Color3.fromRGB(56, 6, 12),
	tile = Color3.fromRGB(152, 34, 46),
	textEdge = Color3.fromRGB(40, 4, 10),
	current = Color3.fromRGB(150, 255, 160),
	poor = Color3.fromRGB(255, 150, 150),
}

export type Spec = { id: string, name: string, icon: string }

export type Row = {
	upgrade: Kit.Button,
	levelBox: Kit.Button,
	title: TextLabel,
	price: TextLabel,
	priceIcon: Frame,
	current: TextLabel,
	level: TextLabel,
}

export type RowState = { current: string, price: string, level: string, affordable: boolean, maxed: boolean }

export type Refs = {
	root: Frame,
	scale: UIScale,
	close: Kit.Button,
	rows: { [string]: Row },
	lights: Kit.Lights,
}

local function buildRow(window: Frame, spec: Spec, index: number): Row
	local row = Kit.make("Frame", {
		Name = spec.id,
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.row,
		Position = UDim2.fromOffset(12, ROWS_TOP + (index - 1) * (ROW_HEIGHT + ROW_GAP)),
		Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
	}, window)
	Kit.corner(row, 12)
	Kit.stroke(row, COLORS.rowEdge, 2)

	local tile = Kit.make("Frame", {
		Name = "IconTile",
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.tile,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(62, 62),
	}, row)
	Kit.corner(tile, 10)
	Kit.stroke(tile, COLORS.rowEdge, 2)
	Kit.icon(tile, spec.icon, UDim2.fromScale(0.5, 0.5), Vector2.new(50, 50), Vector2.new(0.5, 0.5))

	Kit.label(row, {
		name = "Name",
		text = spec.name,
		position = UDim2.fromOffset(80, 12),
		size = UDim2.fromOffset(176, 24),
		stroke = COLORS.textEdge,
		strokeThickness = 2,
		maxTextSize = 19,
		xAlign = Enum.TextXAlignment.Left,
	})
	local current = Kit.label(row, {
		name = "Current",
		text = "",
		position = UDim2.fromOffset(80, 44),
		size = UDim2.fromOffset(176, 18),
		color = COLORS.current,
		stroke = COLORS.textEdge,
		strokeThickness = 2,
		maxTextSize = 14,
		xAlign = Enum.TextXAlignment.Left,
	})

	local upgradeSize = Vector2.new(124, 56)
	local levelSize = Vector2.new(58, 56)
	local centerY = 9 + (upgradeSize.Y + Kit.DEPTH) / 2
	local upgrade = Kit.button(row, {
		name = "Upgrade",
		size = upgradeSize,
		position = UDim2.fromOffset(ROW_WIDTH - 8 - levelSize.X - 10 - upgradeSize.X / 2, centerY),
		scheme = Kit.Schemes.gold,
		radius = 10,
	})
	local title = Kit.label(upgrade.face, {
		name = "Title",
		text = "UPGRADE",
		position = UDim2.new(0.5, 0, 0, 7),
		anchor = Vector2.new(0.5, 0),
		size = UDim2.new(1, -16, 0, 16),
		stroke = Kit.Schemes.gold.edge,
		strokeThickness = 2,
		maxTextSize = 15,
	})
	local priceIcon = Kit.icon(upgrade.face, "cash", UDim2.fromOffset(12, 28), Vector2.new(24, 21))
	local price = Kit.label(upgrade.face, {
		name = "Price",
		text = "",
		position = UDim2.fromOffset(40, 28),
		size = UDim2.fromOffset(upgradeSize.X - 40 - 10, 21),
		stroke = Kit.Schemes.gold.edge,
		strokeThickness = 2,
		maxTextSize = 18,
		xAlign = Enum.TextXAlignment.Left,
	})

	local levelBox = Kit.button(row, {
		name = "Level",
		size = levelSize,
		position = UDim2.fromOffset(ROW_WIDTH - 8 - levelSize.X / 2, centerY),
		scheme = Kit.Schemes.ice,
		radius = 10,
	})
	levelBox.button.Active = false
	Kit.label(levelBox.face, {
		name = "Caption",
		text = "LV",
		position = UDim2.new(0.5, 0, 0, 6),
		anchor = Vector2.new(0.5, 0),
		size = UDim2.new(1, -12, 0, 13),
		stroke = Kit.Schemes.ice.edge,
		strokeThickness = 2,
		maxTextSize = 12,
	})
	local level = Kit.label(levelBox.face, {
		name = "Value",
		text = "0",
		position = UDim2.new(0.5, 0, 0, 21),
		anchor = Vector2.new(0.5, 0),
		size = UDim2.new(1, -10, 0, 27),
		stroke = Kit.Schemes.ice.edge,
		strokeThickness = 3,
		maxTextSize = 24,
	})

	return {
		upgrade = upgrade,
		levelBox = levelBox,
		title = title,
		price = price,
		priceIcon = priceIcon,
		current = current,
		level = level,
	}
end

function UpgradesView.build(gui: ScreenGui, specs: { Spec }): Refs
	local height = ROWS_TOP + #specs * (ROW_HEIGHT + ROW_GAP) - ROW_GAP + 14
	local root = Kit.make("Frame", {
		Name = "UpgradesWindow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 24),
		Size = UDim2.fromOffset(WIDTH, height + 6),
		Visible = false,
		ZIndex = 10,
	}, gui)
	local scale = Kit.make("UIScale", {}, root)

	local shadow = Kit.make("Frame", {
		Name = "Shadow",
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.shadow,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(WIDTH, height),
		ZIndex = 1,
	}, root)
	Kit.corner(shadow, 18)

	local window = Kit.make("Frame", {
		Name = "Panel",
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.panel,
		Size = UDim2.fromOffset(WIDTH, height),
		ZIndex = 2,
	}, root)
	Kit.corner(window, 18)
	Kit.stroke(window, Kit.Colors.white, 4)
	Kit.snowCap(window, WIDTH, 3)
	local lights = Kit.lights(window, Vector2.new(WIDTH, height), 10, 18, 26)

	local headerSize = Vector2.new(WIDTH - 16, HEADER_HEIGHT)
	local header = Kit.make("CanvasGroup", {
		Name = "Header",
		BorderSizePixel = 0,
		BackgroundColor3 = Kit.Schemes.green.base,
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.fromOffset(headerSize.X, headerSize.Y),
	}, window)
	Kit.corner(header, 12)
	Kit.studs(header, headerSize, Kit.Schemes.green)
	Kit.innerOutline(header, 12, Kit.Schemes.green.edge, 3)
	Kit.icon(header, "tree", UDim2.new(0, 10, 0.5, 0), Vector2.new(46, 46), Vector2.new(0, 0.5))
	Kit.label(header, {
		name = "Title",
		text = "UPGRADES",
		position = UDim2.new(0, 64, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		size = UDim2.fromOffset(300, 34),
		stroke = Kit.Schemes.green.edge,
		strokeThickness = 3,
		maxTextSize = 30,
		xAlign = Enum.TextXAlignment.Left,
	})

	local closeSize = Vector2.new(46, 46)
	local close = Kit.button(window, {
		name = "Close",
		size = closeSize,
		position = UDim2.fromOffset(8 + headerSize.X - 8 - closeSize.X / 2, 10 + headerSize.Y / 2),
		scheme = Kit.Schemes.red,
		radius = 10,
		text = "X",
		maxTextSize = 26,
	})

	local rows = {}
	for index, spec in specs do
		rows[spec.id] = buildRow(window, spec, index)
	end

	return { root = root, scale = scale, close = close, rows = rows, lights = lights }
end

local GREY = Color3.fromRGB(150, 150, 150)

function UpgradesView.setRow(row: Row, state: RowState)
	row.current.Text = state.current
	row.level.Text = state.level
	row.price.Text = state.price
	row.price.TextColor3 = if state.affordable then Kit.Colors.white else COLORS.poor
	row.price.Visible = not state.maxed
	row.priceIcon.Visible = not state.maxed
	row.title.Text = if state.maxed then "MAXED" else "UPGRADE"
	row.title.Position = if state.maxed then UDim2.new(0.5, 0, 0, 18) else UDim2.new(0.5, 0, 0, 7)
	row.upgrade.face.GroupColor3 = if state.maxed then GREY else Kit.Colors.white
end

return UpgradesView
