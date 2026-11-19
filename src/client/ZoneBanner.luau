--!strict
-- Rounded, studded banner that slides down from the top of the screen with the zone name, then hides.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SHOW_TIME = 2.5
local CARD_SIZE = Vector2.new(360, 92)
local MARGIN = 4 -- room for the outline inside the CanvasGroup, which clips its children
local HIDDEN_POSITION = UDim2.new(0.5, 0, 0, -(CARD_SIZE.Y + 2 * MARGIN + 10))
local SHOWN_POSITION = UDim2.new(0.5, 0, 0, 14)

local STUD_SPACING, STUD_SIZE, STUD_INSET = 18, 11, 10
local COLORS = {
	card = Color3.fromRGB(70, 146, 226),
	outline = Color3.fromRGB(255, 255, 255),
	studShadow = Color3.fromRGB(48, 112, 194),
	studLight = Color3.fromRGB(126, 188, 246),
	studDark = Color3.fromRGB(82, 156, 232),
	subtitle = Color3.fromRGB(222, 240, 255),
	textStroke = Color3.fromRGB(22, 52, 104),
}
local FONT = Font.fromEnum(Enum.Font.Arcade)

local ZoneBanner = {}

local root: CanvasGroup
local title: TextLabel
local subtitle: TextLabel
local showToken = 0

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

local function buildStuds(card: Frame)
	local columns = math.floor((CARD_SIZE.X - 2 * STUD_INSET) / STUD_SPACING)
	local rows = math.floor((CARD_SIZE.Y - 2 * STUD_INSET) / STUD_SPACING)
	-- Centre the grid so the gaps on both sides match.
	local offsetX = (CARD_SIZE.X - columns * STUD_SPACING) / 2 + (STUD_SPACING - STUD_SIZE) / 2
	local offsetY = (CARD_SIZE.Y - rows * STUD_SPACING) / 2 + (STUD_SPACING - STUD_SIZE) / 2

	local studs = Instance.new("Frame")
	studs.Name = "Studs"
	studs.BackgroundTransparency = 1
	studs.Size = UDim2.fromScale(1, 1)
	studs.Parent = card

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local x, y = offsetX + column * STUD_SPACING, offsetY + row * STUD_SPACING

			local shadow = Instance.new("Frame")
			shadow.BorderSizePixel = 0
			shadow.BackgroundColor3 = COLORS.studShadow
			shadow.Size = UDim2.fromOffset(STUD_SIZE, STUD_SIZE)
			shadow.Position = UDim2.fromOffset(x + 2, y + 2)
			corner(shadow, UDim.new(1, 0))
			shadow.Parent = studs

			local stud = Instance.new("Frame")
			stud.BorderSizePixel = 0
			stud.BackgroundColor3 = Color3.new(1, 1, 1)
			stud.Size = UDim2.fromOffset(STUD_SIZE, STUD_SIZE)
			stud.Position = UDim2.fromOffset(x, y)
			corner(stud, UDim.new(1, 0))
			local shading = Instance.new("UIGradient")
			shading.Rotation = 45
			shading.Color = ColorSequence.new(COLORS.studLight, COLORS.studDark)
			shading.Parent = stud
			stud.Parent = studs
		end
	end
end

local function label(name: string, parent: Instance, position: UDim2, size: UDim2, color: Color3, maxTextSize: number, strokeThickness: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = position
	text.Size = size
	text.FontFace = FONT
	text.TextColor3 = color
	text.TextScaled = true
	text.ZIndex = 2
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxTextSize
	limit.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.textStroke
	stroke.Thickness = strokeThickness
	stroke.Parent = text
	text.Parent = parent
	return text
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ZoneBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	root = Instance.new("CanvasGroup")
	root.Name = "Banner"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Size = UDim2.fromOffset(CARD_SIZE.X + 2 * MARGIN, CARD_SIZE.Y + 2 * MARGIN)
	root.Position = HIDDEN_POSITION
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.Visible = false
	root.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BorderSizePixel = 0
	card.BackgroundColor3 = COLORS.card
	card.Position = UDim2.fromOffset(MARGIN, MARGIN)
	card.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	corner(card, UDim.new(0, 18))
	local outline = Instance.new("UIStroke")
	outline.Color = COLORS.outline
	outline.Thickness = 3
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = card
	card.Parent = root

	buildStuds(card)
	subtitle = label("Subtitle", card, UDim2.new(0.5, 0, 0, 14), UDim2.new(1, -40, 0, 16), COLORS.subtitle, 14, 2)
	title = label("Title", card, UDim2.new(0.5, 0, 0, 38), UDim2.new(1, -40, 0, 38), Color3.new(1, 1, 1), 30, 3)

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
end

function ZoneBanner.show(zoneName: string, zoneSubtitle: string?)
	if not root then
		build()
	end
	showToken += 1
	local token = showToken

	title.Text = zoneName
	subtitle.Text = zoneSubtitle or ""
	if not root.Visible then
		root.Position = HIDDEN_POSITION
		root.GroupTransparency = 1
		root.Visible = true
	end

	TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN_POSITION }):Play()
	TweenService:Create(root, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()

	task.delay(SHOW_TIME, function()
		if token ~= showToken then
			return -- a newer zone replaced this banner
		end
		local hide = TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = HIDDEN_POSITION,
			GroupTransparency = 1,
		})
		hide.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and token == showToken then
				root.Visible = false
			end
		end)
		hide:Play()
	end)
end

return ZoneBanner
