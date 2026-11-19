--!strict
-- Brings the Elf Village elves to life on this client: each elf paces between its WalkFrom and WalkTo
-- points (attributes set by the map generator), swinging its arms and legs, pausing and turning at
-- each end. Above every elf floats its name and a marker for the local player's missions:
-- "!" = has a task for you, "?" = your task for this elf is done (come back), "..." = in progress.
-- Elves are anchored and only move locally; the server's Talk prompt sits on a fixed TalkSpot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Missions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Missions"))
local Kit = require(script.Parent.Ui.Kit)

local WALK_SPEED = 4
local PAUSE = 2.5
local TURN_TIME = 0.4
local SWING = math.rad(32)
local STRIDE = 1.6 -- studs per half step
local ANIMATE_DISTANCE = 260

type Piece = { part: BasePart, offset: CFrame, limb: string? }
type Elf = {
	model: Model,
	id: string,
	from: Vector3,
	to: Vector3,
	hipY: number,
	shoulderY: number,
	pieces: { Piece },
	marker: TextLabel,
	phase: number,
}

local Elves = {}

local MARKER_COLORS = {
	available = Color3.fromRGB(255, 214, 60),
	done = Color3.fromRGB(110, 240, 120),
	busy = Color3.fromRGB(230, 236, 245),
}

local function setup(model: Model, gui: Folder): Elf?
	local root = model:WaitForChild("Root", 10) :: BasePart?
	local id, from, to = model:GetAttribute("ElfId"), model:GetAttribute("WalkFrom"), model:GetAttribute("WalkTo")
	if not root or typeof(id) ~= "string" or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return nil
	end
	local hipY, shoulderY = model:GetAttribute("HipY"), model:GetAttribute("ShoulderY")

	local pieces: { Piece } = {}
	local head: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "TalkSpot" then
			local limb = descendant:GetAttribute("Limb")
			table.insert(pieces, {
				part = descendant,
				offset = root.CFrame:ToObjectSpace(descendant.CFrame),
				limb = if typeof(limb) == "string" then limb else nil,
			})
			if descendant.Name == "Head" then
				head = descendant
			end
		end
	end

	local tag = Kit.make("BillboardGui", {
		Name = `{id}Tag`,
		Adornee = head or root,
		Size = UDim2.fromOffset(150, 64),
		StudsOffset = Vector3.new(0, 2.8, 0),
		MaxDistance = 90,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, gui)
	local marker = Kit.label(tag, {
		name = "Marker",
		text = "",
		position = UDim2.fromScale(0.5, 0),
		anchor = Vector2.new(0.5, 0),
		size = UDim2.new(1, 0, 0, 30),
		color = MARKER_COLORS.available,
		stroke = Color3.fromRGB(40, 30, 10),
		strokeThickness = 3,
		maxTextSize = 30,
	})
	local elfName = model:GetAttribute("ElfName")
	Kit.label(tag, {
		name = "Name",
		text = if typeof(elfName) == "string" then elfName else id,
		position = UDim2.fromScale(0.5, 1),
		anchor = Vector2.new(0.5, 1),
		size = UDim2.new(1, 0, 0, 22),
		stroke = Color3.fromRGB(16, 70, 24),
		strokeThickness = 2,
		maxTextSize = 18,
	})

	return {
		model = model,
		id = id,
		from = from,
		to = to,
		hipY = if typeof(hipY) == "number" then hipY else 2,
		shoulderY = if typeof(shoulderY) == "number" then shoulderY else 4,
		pieces = pieces,
		marker = marker,
		phase = math.random() * 10,
	}
end

-- Where the elf is `t` seconds into its walk loop: position, facing and how fast its limbs swing.
local function pose(elf: Elf, t: number): (Vector3, Vector3, number)
	local delta = elf.to - elf.from
	local length = delta.Magnitude
	local walk = length / WALK_SPEED
	local cycle = 2 * (walk + PAUSE)
	local u = t % cycle
	local direction = delta.Unit
	if u < walk then
		return elf.from + direction * (u * WALK_SPEED), direction, 1
	elseif u < walk + PAUSE then
		local turn = math.clamp((u - walk - PAUSE + TURN_TIME) / TURN_TIME, 0, 1)
		return elf.to, direction:Lerp(-direction + Vector3.new(0.001, 0, 0), turn).Unit, 0
	elseif u < 2 * walk + PAUSE then
		return elf.to - direction * ((u - walk - PAUSE) * WALK_SPEED), -direction, 1
	end
	local turn = math.clamp((u - 2 * walk - 2 * PAUSE + TURN_TIME) / TURN_TIME, 0, 1)
	return elf.from, (-direction):Lerp(direction + Vector3.new(0.001, 0, 0), turn).Unit, 0
end

local function animate(elf: Elf, t: number, parts: { BasePart }, frames: { CFrame })
	local time = t + elf.phase
	local position, facing, walking = pose(elf, time)
	-- One full leg swing per two strides.
	local stride = math.sin(time * WALK_SPEED / STRIDE * math.pi / 2) * walking
	local lift = Vector3.new(0, 0.1 + math.abs(stride) * 0.12, 0)
	local base = CFrame.lookAt(position + lift, position + lift + facing)
	local swingAngle = stride * SWING
	for _, piece in elf.pieces do
		local offset = piece.offset
		local limb = piece.limb
		if limb then
			local pivotY = if limb == "LegL" or limb == "LegR" then elf.hipY else elf.shoulderY
			local sign = if limb == "LegL" or limb == "ArmR" then 1 else -1
			local swing = CFrame.new(0, pivotY, 0) * CFrame.Angles(swingAngle * sign, 0, 0) * CFrame.new(0, -pivotY, 0)
			offset = swing * offset
		end
		table.insert(parts, piece.part)
		table.insert(frames, base * offset)
	end
end

local function refreshMarkers(elves: { Elf }, player: Player)
	local active = Missions.activeElf(player)
	local done = Missions.isDone(player)
	for _, elf in elves do
		if not active then
			elf.marker.Text = "!"
			elf.marker.TextColor3 = MARKER_COLORS.available
		elseif active == elf.id then
			elf.marker.Text = if done then "?" else "..."
			elf.marker.TextColor3 = if done then MARKER_COLORS.done else MARKER_COLORS.busy
		else
			elf.marker.Text = ""
		end
	end
end

function Elves.start()
	local player = Players.LocalPlayer :: Player
	local container = Workspace:WaitForChild("Map"):WaitForChild("Spawn"):WaitForChild("Village"):WaitForChild("Elves")
	local gui = Instance.new("Folder")
	gui.Name = "ElfTags"
	gui.Parent = player:WaitForChild("PlayerGui")

	local elves: { Elf } = {}
	for _, model in container:GetChildren() do
		if model:IsA("Model") then
			local elf = setup(model, gui)
			if elf then
				table.insert(elves, elf)
			end
		end
	end

	local function refresh()
		refreshMarkers(elves, player)
	end
	for _, attribute in { "MissionElf", "MissionProgress", "MissionGoal" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()

	local start = os.clock()
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock() - start
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for _, elf in elves do
			if (camera.CFrame.Position - elf.from).Magnitude < ANIMATE_DISTANCE then
				animate(elf, t, parts, frames)
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Elves
