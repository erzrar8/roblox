--!strict
-- Rounded, studded banner that slides down from the top of the screen with the zone name, then hides.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Ui.Kit)

local SHOW_TIME = 2.5
local CARD_SIZE = Vector2.new(260, 60)
local CORNER_RADIUS = 14
local OUTLINE = 3
-- Just below the HUD top bar (UPGRADES / SELL), which sits at the top centre of the screen.
local SHOWN_POSITION = UDim2.new(0.5, 0, 0, 100)
local HIDDEN_POSITION = UDim2.new(0.5, 0, 0, -(CARD_SIZE.Y + 10))

local COLORS = {
	card = Color3.fromRGB(70, 146, 226),
	outline = Color3.fromRGB(255, 255, 255),
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

-- Fills the whole card edge to edge; the CanvasGroup's UICorner clips the studs at the rounded corners.
local function buildStuds(card: CanvasGroup)
	Kit.studs(card, CARD_SIZE, Kit.Schemes.ice)
end

-- UIStroke draws outside its frame, so a frame inset by the stroke width keeps the outline inside
-- the card, where the CanvasGroup can fade it together with everything else.
local function buildOutline(card: CanvasGroup)
	local frame = Instance.new("Frame")
	frame.Name = "Outline"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(OUTLINE, OUTLINE)
	frame.Size = UDim2.new(1, -2 * OUTLINE, 1, -2 * OUTLINE)
	frame.ZIndex = 3
	corner(frame, UDim.new(0, CORNER_RADIUS - OUTLINE))
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.outline
	stroke.Thickness = OUTLINE
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	frame.Parent = card
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
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	root = Instance.new("CanvasGroup")
	root.Name = "Banner"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	root.Position = HIDDEN_POSITION
	root.BackgroundColor3 = COLORS.card
	root.BorderSizePixel = 0
	root.GroupTransparency = 1
	root.Visible = false
	corner(root, UDim.new(0, CORNER_RADIUS))
	root.Parent = gui

	buildStuds(root)
	buildOutline(root)
	subtitle = label("Subtitle", root, UDim2.new(0.5, 0, 0, 10), UDim2.new(1, -32, 0, 11), COLORS.subtitle, 10, 1.5)
	title = label("Title", root, UDim2.new(0.5, 0, 0, 26), UDim2.new(1, -32, 0, 24), Color3.new(1, 1, 1), 20, 2.5)

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
