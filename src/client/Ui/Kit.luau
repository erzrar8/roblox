--!strict
-- Building blocks for the festive, studded UI. Pure builders (no services), so the HUD can also be
-- built outside Roblox for previews. Icons are drawn from frames, so no image uploads are needed.
local Kit = {}

Kit.FONT = Font.fromEnum(Enum.Font.Arcade)
Kit.DEPTH = 4 -- height of the darker "3D" edge under buttons

export type Scheme = { base: Color3, light: Color3, dark: Color3, shadow: Color3, edge: Color3 }

local rgb = Color3.fromRGB
Kit.Schemes = {
	red = { base = rgb(214, 48, 52), light = rgb(244, 108, 108), dark = rgb(208, 42, 46), shadow = rgb(160, 26, 32), edge = rgb(104, 12, 18) },
	green = { base = rgb(62, 176, 74), light = rgb(122, 222, 122), dark = rgb(58, 168, 70), shadow = rgb(34, 124, 48), edge = rgb(16, 78, 28) },
	gold = { base = rgb(246, 186, 36), light = rgb(255, 226, 112), dark = rgb(242, 178, 28), shadow = rgb(198, 134, 8), edge = rgb(122, 76, 0) },
	ice = { base = rgb(70, 146, 226), light = rgb(126, 188, 246), dark = rgb(82, 156, 232), shadow = rgb(48, 112, 194), edge = rgb(22, 52, 104) },
} :: { [string]: Scheme }

Kit.Colors = {
	white = rgb(255, 255, 255),
	snow = rgb(246, 250, 255),
	wire = rgb(28, 58, 34),
	bulbs = { rgb(255, 72, 72), rgb(255, 212, 60), rgb(84, 224, 104), rgb(86, 172, 255) },
}

function Kit.make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = (Instance.new :: any)(className)
	for key, value in props do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.corner(parent: Instance, radius: number | UDim): UICorner
	local value = if typeof(radius) == "UDim" then radius else UDim.new(0, radius :: number)
	return Kit.make("UICorner", { CornerRadius = value }, parent)
end

-- Border stroke drawn outside the frame.
function Kit.stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return Kit.make("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

-- Outline drawn just inside a frame, so a CanvasGroup parent does not clip it and it fades with the group.
function Kit.innerOutline(parent: GuiObject, radius: number, color: Color3, thickness: number, zIndex: number?): Frame
	local frame = Kit.make("Frame", {
		Name = "Outline",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(thickness, thickness),
		Size = UDim2.new(1, -2 * thickness, 1, -2 * thickness),
		ZIndex = zIndex or 4,
	}, parent)
	Kit.corner(frame, math.max(radius - thickness, 0))
	Kit.stroke(frame, color, thickness)
	return frame
end

-- Lego-style studs covering `size` edge to edge; a rounded CanvasGroup parent clips them at the corners.
function Kit.studs(parent: GuiObject, size: Vector2, scheme: Scheme, spacing: number?, studSize: number?): Frame
	local step = spacing or 13
	local stud = studSize or 8
	local columns = math.ceil(size.X / step) + 1
	local rows = math.ceil(size.Y / step) + 1
	local offsetX = (size.X - columns * step) / 2 + (step - stud) / 2
	local offsetY = (size.Y - rows * step) / 2 + (step - stud) / 2

	local studs = Kit.make("Frame", { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, parent)
	local shading = ColorSequence.new(scheme.light, scheme.dark)
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local x, y = offsetX + column * step, offsetY + row * step
			local shadow = Kit.make("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = scheme.shadow,
				Size = UDim2.fromOffset(stud, stud),
				Position = UDim2.fromOffset(x + 1.5, y + 1.5),
				ZIndex = 1,
			}, studs)
			Kit.corner(shadow, UDim.new(1, 0))
			local top = Kit.make("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = Kit.Colors.white,
				Size = UDim2.fromOffset(stud, stud),
				Position = UDim2.fromOffset(x, y),
				ZIndex = 1,
			}, studs)
			Kit.corner(top, UDim.new(1, 0))
			Kit.make("UIGradient", { Rotation = 45, Color = shading }, top)
		end
	end
	return studs
end

export type LabelOptions = {
	name: string?,
	text: string,
	position: UDim2,
	size: UDim2,
	anchor: Vector2?,
	color: Color3?,
	stroke: Color3?,
	strokeThickness: number?,
	maxTextSize: number,
	xAlign: Enum.TextXAlignment?,
	zIndex: number?,
}

-- Pixel-font label with an outline, scaled to fit its box up to maxTextSize.
function Kit.label(parent: Instance, o: LabelOptions): TextLabel
	local label = Kit.make("TextLabel", {
		Name = o.name or "Label",
		BackgroundTransparency = 1,
		Position = o.position,
		Size = o.size,
		AnchorPoint = o.anchor or Vector2.zero,
		FontFace = Kit.FONT,
		Text = o.text,
		TextColor3 = o.color or Kit.Colors.white,
		TextScaled = true,
		TextXAlignment = o.xAlign or Enum.TextXAlignment.Center,
		ZIndex = o.zIndex or 5,
	}, parent)
	Kit.make("UITextSizeConstraint", { MaxTextSize = o.maxTextSize }, label)
	if o.stroke then
		Kit.make("UIStroke", { Color = o.stroke, Thickness = o.strokeThickness or 2 }, label)
	end
	return label
end

export type ButtonOptions = {
	name: string,
	size: Vector2,
	position: UDim2, -- centre of the button
	scheme: Scheme,
	radius: number?,
	text: string?,
	maxTextSize: number?,
}

export type Button = { button: TextButton, face: CanvasGroup, scale: UIScale, label: TextLabel? }

-- Studded "3D" button: a darker edge under a rounded, studded face with a glossy top.
function Kit.button(parent: Instance, o: ButtonOptions): Button
	local radius = o.radius or 12
	local button = Kit.make("TextButton", {
		Name = o.name,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = o.position,
		Size = UDim2.fromOffset(o.size.X, o.size.Y + Kit.DEPTH),
	}, parent)
	local scale = Kit.make("UIScale", {}, button)
	local edge = Kit.make("Frame", {
		Name = "Edge",
		BorderSizePixel = 0,
		BackgroundColor3 = o.scheme.edge,
		Position = UDim2.fromOffset(0, Kit.DEPTH),
		Size = UDim2.fromOffset(o.size.X, o.size.Y),
		ZIndex = 1,
	}, button)
	Kit.corner(edge, radius)
	local face = Kit.make("CanvasGroup", {
		Name = "Face",
		BorderSizePixel = 0,
		BackgroundColor3 = o.scheme.base,
		Size = UDim2.fromOffset(o.size.X, o.size.Y),
		ZIndex = 2,
	}, button)
	Kit.corner(face, radius)
	Kit.studs(face, o.size, o.scheme)
	Kit.make("Frame", {
		Name = "Shine",
		BorderSizePixel = 0,
		BackgroundColor3 = Kit.Colors.white,
		BackgroundTransparency = 0.82,
		Size = UDim2.fromScale(1, 0.42),
		ZIndex = 2,
	}, face)
	Kit.innerOutline(face, radius, o.scheme.edge, 3)

	local label
	if o.text then
		label = Kit.label(face, {
			text = o.text,
			position = UDim2.fromScale(0.5, 0.5),
			anchor = Vector2.new(0.5, 0.5),
			size = UDim2.new(1, -20, 1, -14),
			stroke = o.scheme.edge,
			strokeThickness = 3,
			maxTextSize = o.maxTextSize or 26,
		})
	end
	return { button = button, face = face, scale = scale, label = label }
end

-- White snow lumps along the top edge of a panel `width` pixels wide.
function Kit.snowCap(parent: GuiObject, width: number, seed: number)
	local random = Random.new(seed)
	local x = 4
	while x < width - 4 do
		local w = random:NextInteger(18, 30)
		local h = random:NextInteger(9, 13)
		local lump = Kit.make("Frame", {
			Name = "Snow",
			BorderSizePixel = 0,
			BackgroundColor3 = Kit.Colors.snow,
			Position = UDim2.fromOffset(math.min(x, width - 4 - w), -h * 0.45),
			Size = UDim2.fromOffset(w, h),
			ZIndex = 6,
		}, parent)
		Kit.corner(lump, UDim.new(0.5, 0))
		x += w - 6
	end
end

export type Lights = { bulbs: { Frame }, colors: { Color3 } }

-- A string of Christmas lights around a `size` rectangle: the wire runs `inset` pixels outside its edge
-- and the bulbs hang outwards from it.
function Kit.lights(parent: GuiObject, size: Vector2, inset: number, radius: number, spacing: number): Lights
	local width, height = size.X + 2 * inset, size.Y + 2 * inset
	local wire = Kit.make("Frame", {
		Name = "LightsWire",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-inset, -inset),
		Size = UDim2.fromOffset(width, height),
		ZIndex = 7,
	}, parent)
	Kit.corner(wire, radius + inset)
	Kit.stroke(wire, Kit.Colors.wire, 2)

	local bulbs, colors = {}, {}
	local function place(x: number, y: number, rotation: number)
		local color = Kit.Colors.bulbs[#bulbs % #Kit.Colors.bulbs + 1]
		-- The bulb hangs away from the wire: rotate the socket end onto the wire point.
		local angle = math.rad(rotation)
		local cx, cy = x - math.sin(angle) * 6, y + math.cos(angle) * 6
		local bulb = Kit.make("Frame", {
			Name = "Bulb",
			BorderSizePixel = 0,
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(10, 14),
			Rotation = rotation,
			ZIndex = 8,
		}, wire)
		Kit.corner(bulb, UDim.new(0.5, 0))
		Kit.make("Frame", {
			Name = "Socket",
			BorderSizePixel = 0,
			BackgroundColor3 = Kit.Colors.wire,
			Position = UDim2.fromOffset(1.5, -1),
			Size = UDim2.fromOffset(7, 5),
			ZIndex = 9,
		}, bulb)
		table.insert(bulbs, bulb)
		table.insert(colors, color)
	end

	local function edge(length: number, at: (number) -> (number, number), rotation: number)
		local usable = length - 2 * (radius + inset)
		local count = math.max(1, math.floor(usable / spacing) + 1)
		for i = 0, count - 1 do
			local t = if count == 1 then 0.5 else i / (count - 1)
			local x, y = at(radius + inset + usable * t)
			place(x, y, rotation)
		end
	end
	edge(width, function(d)
		return d, 0
	end, 180)
	edge(height, function(d)
		return width, d
	end, -90)
	edge(width, function(d)
		return width - d, height
	end, 0)
	edge(height, function(d)
		return 0, height - d
	end, 90)
	return { bulbs = bulbs, colors = colors }
end

-- Icons are drawn in a unit box, so they scale to any size.
local function shape(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, props: { [string]: any }?): Frame
	local frame = Kit.make("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		ZIndex = 6,
	}, parent)
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	return frame
end

local function ball(parent: Instance, x: number, y: number, d: number)
	local frame = shape(parent, x, y, d, d, rgb(250, 252, 255))
	Kit.corner(frame, UDim.new(0.5, 0))
	Kit.make("UIGradient", { Rotation = 45, Color = ColorSequence.new(rgb(255, 255, 255), rgb(176, 206, 238)) }, frame)
	Kit.stroke(frame, rgb(96, 140, 196), 2)
	local shine = shape(frame, 0.2, 0.16, 0.26, 0.2, rgb(255, 255, 255), { ZIndex = 7 })
	Kit.corner(shine, UDim.new(0.5, 0))
end

local ICONS: { [string]: (Frame) -> () } = {
	cash = function(box)
		local greens = { rgb(40, 138, 48), rgb(52, 160, 60), rgb(76, 196, 84) }
		for i, y in { 0.58, 0.43, 0.28 } do
			local bill = shape(box, 0.06, y, 0.88, 0.3, greens[i])
			Kit.corner(bill, UDim.new(0.25, 0))
			Kit.stroke(bill, rgb(16, 76, 26), 2)
		end
		local oval = shape(box, 0.16, 0.34, 0.3, 0.18, rgb(48, 150, 58), { ZIndex = 7 })
		Kit.corner(oval, UDim.new(0.5, 0))
		local band = shape(box, 0.56, 0.24, 0.17, 0.68, rgb(252, 200, 44), { ZIndex = 8 })
		Kit.corner(band, UDim.new(0.2, 0))
		Kit.stroke(band, rgb(150, 98, 0), 2)
		shape(band, 0.15, 0.06, 0.25, 0.88, rgb(255, 236, 140), { ZIndex = 9 })
	end,
	snowball = function(box)
		ball(box, 0.1, 0.1, 0.8)
	end,
	bigball = function(box)
		ball(box, 0.02, 0.5, 0.42)
		ball(box, 0.36, 0.1, 0.62)
	end,
	boot = function(box)
		local blue, dark = rgb(66, 136, 226), rgb(20, 56, 120)
		local shaft = shape(box, 0.22, 0.14, 0.34, 0.5, blue)
		Kit.stroke(shaft, dark, 2)
		local foot = shape(box, 0.22, 0.5, 0.64, 0.26, blue)
		Kit.corner(foot, UDim.new(0.45, 0))
		Kit.stroke(foot, dark, 2)
		local sole = shape(box, 0.18, 0.74, 0.72, 0.12, rgb(236, 242, 250), { ZIndex = 7 })
		Kit.corner(sole, UDim.new(0.4, 0))
		local cuff = shape(box, 0.16, 0.06, 0.46, 0.16, rgb(250, 252, 255), { ZIndex = 7 })
		Kit.corner(cuff, UDim.new(0.5, 0))
	end,
	tree = function(box)
		local green, dark = rgb(44, 156, 72), rgb(14, 80, 34)
		shape(box, 0.42, 0.78, 0.16, 0.16, rgb(120, 76, 40))
		for i, tier in { { 0.08, 0.58, 0.84 }, { 0.18, 0.4, 0.64 }, { 0.28, 0.22, 0.44 } } do
			local frame = shape(box, tier[1], tier[2], tier[3], 0.22, green, { ZIndex = 6 + i })
			Kit.corner(frame, UDim.new(0.3, 0))
			Kit.stroke(frame, dark, 2)
		end
		local ornaments: { { x: number, y: number, color: Color3 } } = {
			{ x = 0.24, y = 0.66, color = rgb(255, 72, 72) },
			{ x = 0.62, y = 0.7, color = rgb(255, 212, 60) },
			{ x = 0.46, y = 0.48, color = rgb(86, 172, 255) },
			{ x = 0.36, y = 0.3, color = rgb(255, 72, 72) },
		}
		for _, dot in ornaments do
			local ornament = shape(box, dot.x, dot.y, 0.1, 0.1, dot.color, { ZIndex = 10 })
			Kit.corner(ornament, UDim.new(0.5, 0))
		end
		local star = shape(box, 0.41, 0.02, 0.18, 0.18, rgb(255, 214, 50), { Rotation = 45, ZIndex = 10 })
		Kit.stroke(star, rgb(160, 104, 0), 1.5)
	end,
}

function Kit.icon(parent: Instance, kind: string, position: UDim2, size: Vector2, anchor: Vector2?): Frame
	local box = Kit.make("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 6,
	}, parent)
	local draw = ICONS[kind]
	if draw then
		draw(box)
	end
	return box
end

return Kit
