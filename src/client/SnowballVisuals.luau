--!strict
-- Draws every player's snowball in front of their character, rolls it as they move, and poses the
-- character pushing it (leaning forward while walking, arms on the ball). Purely visual: the server
-- sets SnowballSize and SnowballActive on each player, and every client draws all balls itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SnowballConfig"))

local SIZE_SMOOTHING = 8
local SPEED_SMOOTHING = 10
local ARM_ANGLE_SMALL, ARM_ANGLE_BIG = math.rad(45), math.rad(85)
local LEAN_MAX = math.rad(14)
local LEAN_FULL_SPEED = 10
local FLOOR_RAY = Vector3.new(0, -12, 0)
local FLAT = Vector3.new(1, 0, 1)
local BALL_COLOR = Color3.fromRGB(240, 246, 252)

type PoseJoint = {
	motor: Motor6D,
	original: CFrame,
	apply: (original: CFrame, arms: number, lean: number) -> CFrame,
}

type Visual = {
	ball: Part,
	shown: number,
	rotation: CFrame,
	speed: number,
	lastCenter: Vector3?,
	lastRoot: Vector3?,
	character: Model?,
	joints: { PoseJoint }?,
}

local SnowballVisuals = {}

local folder: Folder
local visuals: { [Player]: Visual } = {}

-- C0 offsets layered on top of the default animations, which only drive Motor6D.Transform.
local function findJoints(character: Model): { PoseJoint }
	local joints: { PoseJoint } = {}
	local function add(motor: Instance?, apply: (CFrame, number, number) -> CFrame)
		if motor and motor:IsA("Motor6D") then
			table.insert(joints, { motor = motor, original = motor.C0, apply = apply })
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		local root = character:FindFirstChild("HumanoidRootPart")
		local torso = character:FindFirstChild("Torso")
		-- R6 has no waist joint, so the whole body leans around the root.
		add(root and root:FindFirstChild("RootJoint"), function(c0: CFrame, _arms: number, lean: number): CFrame
			return CFrame.Angles(-lean, 0, 0) * c0
		end)
		add(torso and torso:FindFirstChild("Right Shoulder"), function(c0: CFrame, arms: number, _lean: number): CFrame
			return c0 * CFrame.Angles(0, 0, arms)
		end)
		add(torso and torso:FindFirstChild("Left Shoulder"), function(c0: CFrame, arms: number, _lean: number): CFrame
			return c0 * CFrame.Angles(0, 0, -arms)
		end)
	else
		local upperTorso = character:FindFirstChild("UpperTorso")
		local rightArm = character:FindFirstChild("RightUpperArm")
		local leftArm = character:FindFirstChild("LeftUpperArm")
		add(upperTorso and upperTorso:FindFirstChild("Waist"), function(c0: CFrame, _arms: number, lean: number): CFrame
			return c0 * CFrame.Angles(-lean, 0, 0)
		end)
		for _, shoulder in { rightArm and rightArm:FindFirstChild("RightShoulder"), leftArm and leftArm:FindFirstChild("LeftShoulder") } do
			add(shoulder, function(c0: CFrame, arms: number, _lean: number): CFrame
				return c0 * CFrame.Angles(arms, 0, 0)
			end)
		end
	end
	return joints
end

local function resetPose(visual: Visual)
	local joints = visual.joints
	if joints then
		for _, joint in joints do
			joint.motor.C0 = joint.original
		end
		visual.joints = nil
	end
end

local function hide(visual: Visual)
	visual.ball.Parent = nil
	visual.lastCenter = nil
	resetPose(visual)
end

local function addPlayer(player: Player)
	local ball = Instance.new("Part")
	ball.Name = `{player.Name}Snowball`
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Snow
	ball.Color = BALL_COLOR
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	visuals[player] = { ball = ball, shown = 0, rotation = CFrame.identity, speed = 0 }
end

local function removePlayer(player: Player)
	local visual = visuals[player]
	if visual then
		resetPose(visual)
		visual.ball:Destroy()
		visuals[player] = nil
	end
end

local function update(player: Player, visual: Visual, dt: number, floorParams: RaycastParams)
	local size = player:GetAttribute("SnowballSize")
	local target = if player:GetAttribute("SnowballActive") == true and typeof(size) == "number" then size else 0
	visual.shown += (target - visual.shown) * (1 - math.exp(-SIZE_SMOOTHING * dt))

	local character = player.Character
	if character ~= visual.character then
		resetPose(visual)
		visual.character = character
		visual.lastRoot = nil
		visual.lastCenter = nil
	end

	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root or visual.shown < 0.05 then
		if target == 0 then
			visual.shown = 0
		end
		hide(visual)
		return
	end

	local rootPosition = root.Position
	local lastRoot = visual.lastRoot
	if lastRoot then
		local speed = ((rootPosition - lastRoot) * FLAT).Magnitude / math.max(dt, 1e-3)
		visual.speed += (speed - visual.speed) * (1 - math.exp(-SPEED_SMOOTHING * dt))
	end
	visual.lastRoot = rootPosition

	local look = root.CFrame.LookVector * FLAT
	if look.Magnitude < 1e-3 then
		return
	end
	look = look.Unit

	-- Ball: on the floor in front of the character, rolling with the distance it travels.
	local diameter = visual.shown
	local radius = diameter / 2
	local hit = Workspace:Raycast(rootPosition, FLOOR_RAY, floorParams)
	local floorY = if hit then hit.Position.Y else rootPosition.Y - 3
	local center = Vector3.new(rootPosition.X, floorY + radius - Config.BALL_SINK, rootPosition.Z) + look * Config.ballOffset(diameter)
	local lastCenter = visual.lastCenter
	if lastCenter then
		local delta = (center - lastCenter) * FLAT
		local distance = delta.Magnitude
		if distance > 1e-3 and distance < 20 then
			local axis = Vector3.yAxis:Cross(delta / distance)
			visual.rotation = (CFrame.fromAxisAngle(axis, distance / radius) * visual.rotation):Orthonormalize()
		end
	end
	visual.lastCenter = center
	visual.ball.Size = Vector3.one * diameter
	visual.ball.CFrame = CFrame.new(center) * visual.rotation
	visual.ball.Parent = folder

	-- Pose: arms reach further up for bigger balls; lean grows with walking speed.
	local joints: { PoseJoint } = visual.joints or findJoints(character)
	visual.joints = joints
	local weight = math.clamp(diameter / Config.START_DIAMETER, 0, 1)
	local reach = math.clamp((diameter - Config.START_DIAMETER) / 8, 0, 1)
	local arms = (ARM_ANGLE_SMALL + (ARM_ANGLE_BIG - ARM_ANGLE_SMALL) * reach) * weight
	local lean = LEAN_MAX * math.clamp(visual.speed / LEAN_FULL_SPEED, 0, 1) * weight
	for _, joint in joints do
		joint.motor.C0 = joint.apply(joint.original, arms, lean)
	end
end

function SnowballVisuals.start()
	folder = Instance.new("Folder")
	folder.Name = "SnowballVisuals"
	folder.Parent = Workspace

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end

	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	RunService.RenderStepped:Connect(function(dt)
		local ignore: { Instance } = { folder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		floorParams.FilterDescendantsInstances = ignore

		for player, visual in visuals do
			update(player, visual, dt, floorParams)
		end
	end)
end

return SnowballVisuals
