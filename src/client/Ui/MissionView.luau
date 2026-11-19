--!strict
-- Builds the elf task tracker shown under the money counter: a red festive panel with the elf's name,
-- the task and a progress bar. Layout only; Hud.luau fills it in.
local Kit = require(script.Parent.Kit)

local MissionView = {}

local SIZE = Vector2.new(250, 96)
local BAR = Vector2.new(SIZE.X - 24, 22)

local COLORS = {
	panel = Color3.fromRGB(124, 22, 32),
	edge = Color3.fromRGB(40, 4, 10),
	title = Color3.fromRGB(255, 214, 70),
	track = Color3.fromRGB(70, 10, 18),
	fill = Color3.fromRGB(70, 196, 84),
	fillDone = Color3.fromRGB(246, 186, 36),
}

export type Refs = {
	root: Frame,
	scale: UIScale,
	title: TextLabel,
	text: TextLabel,
	fill: Frame,
	count: TextLabel,
}

export type State = { elf: string, text: string, progress: number, count: string, done: boolean }

function MissionView.build(gui: ScreenGui): Refs
	local root = Kit.make("Frame", {
		Name = "MissionTracker",
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.panel,
		AnchorPoint = Vector2.new(1, 0),
		-- Under the money counter, right-aligned with it.
		Position = UDim2.new(1, -16, 0, 104),
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		Visible = false,
	}, gui)
	Kit.corner(root, 14)
	Kit.stroke(root, Kit.Colors.white, 3)
	Kit.snowCap(root, SIZE.X, 19)
	local scale = Kit.make("UIScale", {}, root)

	Kit.icon(root, "tree", UDim2.fromOffset(10, 8), Vector2.new(28, 28))
	local title = Kit.label(root, {
		name = "Title",
		text = "",
		position = UDim2.fromOffset(44, 12),
		size = UDim2.fromOffset(SIZE.X - 56, 18),
		color = COLORS.title,
		stroke = COLORS.edge,
		strokeThickness = 2,
		maxTextSize = 15,
		xAlign = Enum.TextXAlignment.Left,
	})
	local text = Kit.label(root, {
		name = "Task",
		text = "",
		position = UDim2.fromOffset(12, 40),
		size = UDim2.fromOffset(SIZE.X - 24, 16),
		stroke = COLORS.edge,
		strokeThickness = 2,
		maxTextSize = 13,
		xAlign = Enum.TextXAlignment.Left,
	})

	local track = Kit.make("Frame", {
		Name = "Bar",
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.track,
		Position = UDim2.fromOffset(12, SIZE.Y - BAR.Y - 12),
		Size = UDim2.fromOffset(BAR.X, BAR.Y),
		ZIndex = 2,
	}, root)
	Kit.corner(track, 8)
	Kit.stroke(track, COLORS.edge, 2)
	local fill = Kit.make("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.fill,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 3,
	}, track)
	Kit.corner(fill, 8)
	Kit.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)),
	}, fill)
	local count = Kit.label(track, {
		name = "Count",
		text = "",
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		size = UDim2.new(1, -12, 1, -6),
		stroke = COLORS.edge,
		strokeThickness = 2,
		maxTextSize = 14,
	})

	return { root = root, scale = scale, title = title, text = text, fill = fill, count = count }
end

function MissionView.set(refs: Refs, state: State)
	refs.title.Text = `{string.upper(state.elf)}'S TASK`
	refs.text.Text = if state.done then `Return to {state.elf}!` else state.text
	refs.count.Text = if state.done then "DONE!" else state.count
	refs.fill.Size = UDim2.fromScale(math.clamp(state.progress, 0, 1), 1)
	refs.fill.BackgroundColor3 = if state.done then COLORS.fillDone else COLORS.fill
end

return MissionView
