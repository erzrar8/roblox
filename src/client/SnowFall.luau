--!strict
-- Client-only falling snow: an invisible emitter that follows the camera.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientSettings = require(script.Parent.ClientSettings)

local AREA = 140
local HEIGHT_ABOVE_CAMERA = 45

local SnowFall = {}

function SnowFall.start()
	local camera = Workspace.CurrentCamera

	local emitterPart = Instance.new("Part")
	emitterPart.Name = "SnowEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.CastShadow = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(AREA, 1, AREA)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.LightEmission = 0.3
	emitter.Size = NumberSequence.new(0.45)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.15),
		NumberSequenceKeypoint.new(0.85, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(7, 9)
	emitter.Rate = 120
	emitter.Speed = NumberRange.new(5, 8)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Acceleration = Vector3.new(1.5, 0, 0.8)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Enabled = ClientSettings.get("Snowfall")
	emitter.Parent = emitterPart
	ClientSettings.onChanged("Snowfall", function(on)
		emitter.Enabled = on
		if not on then
			emitter:Clear()
		end
	end)

	emitterPart.Parent = camera

	RunService.RenderStepped:Connect(function()
		local position = camera.CFrame.Position
		emitterPart.CFrame = CFrame.new(position.X, position.Y + HEIGHT_ABOVE_CAMERA, position.Z)
	end)
end

return SnowFall
