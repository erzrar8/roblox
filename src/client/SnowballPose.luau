--!strict
-- Pushing pose for a character rolling a snowball, on top of its normal animations.
--
-- Works with classic Motor6D joints and with Avatar Joint Upgrade AnimationConstraints (the default
-- R15 joints since 2026, where C0 is read-only). Both expose Transform, which the Animator rewrites
-- every frame before PreSimulation, so the pose is written into Transform during PreSimulation as
-- Roblox recommends for procedural animation. Upper body joints are fully taken over (so the walk
-- cycle cannot swing or twist the arms); the legs keep walking.
local SnowballPose = {}

local BEND_SMALL, BEND_BIG = math.rad(42), math.rad(8) -- stooped over a small ball, upright behind a big one
local BEND_SIZE_MIN, BEND_SIZE_MAX = 2, 12 -- ball diameters between which the bend eases off
local ARM_MAX = math.rad(165)
-- Arm angles follow the ball smoothly instead of every bob of the shoulders.
local ARM_SMOOTHING = 6

type Joint = Motor6D | AnimationConstraint
-- bend: torso pitch; legs: R6 hips counter-rotated; arm: shoulder aimed at the ball; hold: kept straight.
type Role = "bend" | "legs" | "arm" | "hold"

type PoseJoint = {
	joint: Joint,
	part0: BasePart,
	pivot: CFrame, -- joint frame in Part0 space (C0, or Attachment0.CFrame)
	role: Role,
	written: CFrame?,
	base: CFrame?,
	angle: number?,
}

export type Rig = { joints: { PoseJoint } }

export type Params = {
	weight: number, -- 0..1 blend in and out of the pose
	diameter: number,
	center: Vector3, -- ball centre in world space
	moving: number, -- 0..1, how fast the character walks
	dt: number,
}

local JOINT_ROLES: { [string]: Role } = {
	-- R15
	Waist = "bend",
	RightShoulder = "arm",
	LeftShoulder = "arm",
	RightElbow = "hold",
	LeftElbow = "hold",
	RightWrist = "hold",
	LeftWrist = "hold",
	-- R6: no waist, so the whole body bends at the root and the hips keep the legs upright.
	RootJoint = "bend",
	["Right Hip"] = "legs",
	["Left Hip"] = "legs",
	["Right Shoulder"] = "arm",
	["Left Shoulder"] = "arm",
}

local function describe(instance: Instance): (Joint?, BasePart?, CFrame?)
	if instance:IsA("Motor6D") then
		local part0 = instance.Part0
		if part0 then
			return instance, part0, instance.C0
		end
	elseif instance:IsA("AnimationConstraint") then
		local attachment = instance.Attachment0
		local part0 = attachment and attachment.Parent
		if attachment and part0 and part0:IsA("BasePart") then
			return instance, part0, attachment.CFrame
		end
	end
	return nil, nil, nil
end

function SnowballPose.rig(character: Model): Rig
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local isR6 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
	local joints: { PoseJoint } = {}
	for _, descendant in character:GetDescendants() do
		local role = JOINT_ROLES[descendant.Name]
		-- "RootJoint" also exists on R15 (LowerTorso), where bending it would tip the legs too.
		if role and not (descendant.Name == "RootJoint" and not isR6) then
			local joint, part0, pivot = describe(descendant)
			if joint and part0 and pivot then
				table.insert(joints, { joint = joint, part0 = part0, pivot = pivot, role = role :: Role })
			end
		end
	end
	return { joints = joints }
end

-- Transform is stored with reduced precision (reading it back can differ by ~1e-5), so compare loosely.
local function nearlyEqual(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and a.XVector:Dot(b.XVector) > 1 - 1e-4 and a.YVector:Dot(b.YVector) > 1 - 1e-4
end

-- Transform as the Animator left it this frame. When nothing overwrote the value written last frame
-- (throttled or missing animator), reuse the value from before the pose so offsets never pile up.
local function animated(pj: PoseJoint): CFrame
	local current = pj.joint.Transform
	local written = pj.written
	if written and nearlyEqual(current, written) then
		return pj.base or CFrame.identity
	end
	pj.base = current
	return current
end

local function setTransform(joint: Joint, transform: CFrame)
	if joint:IsA("Motor6D") then
		(joint :: Motor6D).Transform = transform
	else
		(joint :: AnimationConstraint).Transform = transform
	end
end

local function write(pj: PoseJoint, transform: CFrame)
	setTransform(pj.joint, transform)
	pj.written = transform
end

-- A rotation given in Part0 space, turned into the joint's own frame (rotating about the joint pivot).
local function inJointFrame(pj: PoseJoint, rotation: CFrame): CFrame
	local frame = pj.pivot.Rotation
	return frame:Inverse() * rotation * frame
end

function SnowballPose.bendFor(diameter: number, moving: number): number
	local t = math.clamp((diameter - BEND_SIZE_MIN) / (BEND_SIZE_MAX - BEND_SIZE_MIN), 0, 1)
	return (BEND_SMALL + (BEND_BIG - BEND_SMALL) * t) * (0.75 + 0.25 * moving)
end

function SnowballPose.apply(rig: Rig, params: Params)
	local w = params.weight
	local bend = SnowballPose.bendFor(params.diameter, params.moving)
	local radius = params.diameter / 2
	local follow = 1 - math.exp(-ARM_SMOOTHING * params.dt)

	for _, pj in rig.joints do
		local transform = animated(pj)
		if pj.role == "bend" then
			-- Replaces the animation, so the walk cycle's torso twist cannot swing the arms around.
			write(pj, transform:Lerp(inJointFrame(pj, CFrame.Angles(-bend, 0, 0)), w))
		elseif pj.role == "legs" then
			write(pj, inJointFrame(pj, CFrame.Angles(bend * w, 0, 0)) * transform)
		elseif pj.role == "hold" then
			write(pj, transform:Lerp(CFrame.identity, w))
		else
			-- Point the arm at the nearest spot on the ball: down for a small ball, up for a big one.
			local shoulder = (pj.part0.CFrame * pj.pivot).Position
			local fromBall = shoulder - params.center
			if fromBall.Magnitude > 1e-3 then
				local target = params.center + fromBall.Unit * radius
				local direction = pj.part0.CFrame:VectorToObjectSpace(target - shoulder)
				local aim = math.clamp(math.atan2(-direction.Z, -direction.Y), 0, ARM_MAX)
				local previous = pj.angle
				local angle: number = if previous then previous + (aim - previous) * follow else aim
				pj.angle = angle
				write(pj, transform:Lerp(inJointFrame(pj, CFrame.Angles(angle, 0, 0)), w))
			end
		end
	end
end

-- Hands the joints back to the animations.
function SnowballPose.release(rig: Rig)
	for _, pj in rig.joints do
		local written = pj.written
		if written and nearlyEqual(pj.joint.Transform, written) then
			setTransform(pj.joint, pj.base or CFrame.identity)
		end
		pj.written = nil
		pj.base = nil
		pj.angle = nil
	end
end

return SnowballPose
