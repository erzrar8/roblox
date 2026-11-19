--!strict
-- Draws every player's snowball in front of their character, rolls it as they move, and poses the
-- character pushing it (SnowballPose). Purely visual: the server sets SnowballSize and SnowballActive
-- on each player, and every client draws all balls and poses itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SnowballConfig"))
local SnowballPose = require(script.Parent.SnowballPose)

local SIZE_SMOOTHING = 8
local SPEED_SMOOTHING = 10
local POSE_SMOOTHING = 10
local FULL_SPEED = 10
local FLOOR_RAY = Vector3.new(0, -12, 0)
local FLAT = Vector3.new(1, 0, 1)
local BALL_COLOR = Color3.fromRGB(240, 246, 252)

type Visual = {
	ball: Part,
	shown: number,
	rotation: CFrame,
	speed: number,
	lastCenter: Vector3?,
	lastRoot: Vector3?,
	character: Model?,
	rig: SnowballPose.Rig?,
	poseWeight: number,
}

local SnowballVisuals = {}

local folder: Folder
local visuals: { [Player]: Visual } = {}

local function releasePose(visual: Visual)
	local rig = visual.rig
	if rig then
		SnowballPose.release(rig)
		visual.rig = nil
	end
	visual.poseWeight = 0
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
	visuals[player] = { ball = ball, shown = 0, rotation = CFrame.identity, speed = 0, poseWeight = 0 }
end

local function removePlayer(player: Player)
	local visual = visuals[player]
	if visual then
		releasePose(visual)
		visual.ball:Destroy()
		visuals[player] = nil
	end
end

-- Ball placement, once per rendered frame.
local function updateBall(player: Player, visual: Visual, dt: number, floorParams: RaycastParams)
	local size = player:GetAttribute("SnowballSize")
	local target = if player:GetAttribute("SnowballActive") == true and typeof(size) == "number" then size else 0
	visual.shown += (target - visual.shown) * (1 - math.exp(-SIZE_SMOOTHING * dt))

	local character = player.Character
	if character ~= visual.character then
		releasePose(visual)
		visual.character = character
		visual.lastRoot = nil
		visual.lastCenter = nil
	end

	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root or visual.shown < 0.05 then
		if target == 0 then
			visual.shown = 0
		end
		visual.ball.Parent = nil
		visual.lastCenter = nil
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

	-- On the floor in front of the character, rolling with the distance it travels.
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
end

-- Character pose, once per frame after the Animator has written this frame's joint transforms.
local function updatePose(visual: Visual, dt: number)
	local character = visual.character
	local center = visual.lastCenter
	local visible = character ~= nil and center ~= nil and visual.ball.Parent ~= nil
	local target = if visible then 1 else 0
	visual.poseWeight += (target - visual.poseWeight) * (1 - math.exp(-POSE_SMOOTHING * dt))

	if not visible or not character or not center then
		releasePose(visual)
		return
	end

	local rig = visual.rig or SnowballPose.rig(character)
	visual.rig = rig
	SnowballPose.apply(rig, {
		weight = visual.poseWeight,
		diameter = visual.shown,
		center = center,
		moving = math.clamp(visual.speed / FULL_SPEED, 0, 1),
		time = os.clock(),
	})
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
			updateBall(player, visual, dt, floorParams)
		end
	end)

	RunService.PreSimulation:Connect(function(dt)
		for _, visual in visuals do
			updatePose(visual, dt)
		end
	end)
end

return SnowballVisuals
