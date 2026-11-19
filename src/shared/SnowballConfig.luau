--!strict
-- Snowball tuning, shared by the server (growth, walk speed) and the client (drawing the ball).
local Config = {}

Config.START_DIAMETER = 2
Config.MAX_DIAMETER = 40
-- Snow (studs³) added to the ball for each fresh snow tile it rolls over.
Config.SNOW_PER_TILE = 3
-- Seconds before a collected tile of fresh snow grows back.
Config.REGROW_MIN = 15
Config.REGROW_MAX = 25

Config.BASE_WALK_SPEED = 16
Config.MIN_WALK_SPEED = 7
-- The ball starts slowing its owner down at this diameter; MIN_WALK_SPEED is reached at MAX_DIAMETER.
Config.SLOWDOWN_FROM = 4

-- How far the ball sinks below the floor, so it looks pressed into the snow.
Config.BALL_SINK = 0.3

-- Rough character measurements in studs: heights above the floor, distances in front of the root part.
local HAND_HEIGHT = 4
local HAND_REACH = 1.8
local BODY_HEIGHT = 5
local BODY_FRONT = 0.5

function Config.volumeFromDiameter(diameter: number): number
	return math.pi / 6 * diameter ^ 3
end

function Config.diameterFromVolume(volume: number): number
	return (6 * volume / math.pi) ^ (1 / 3)
end

function Config.walkSpeed(diameter: number): number
	local t = math.clamp((diameter - Config.SLOWDOWN_FROM) / (Config.MAX_DIAMETER - Config.SLOWDOWN_FROM), 0, 1)
	return Config.BASE_WALK_SPEED + (Config.MIN_WALK_SPEED - Config.BASE_WALK_SPEED) * math.sqrt(t)
end

-- Horizontal distance from the HumanoidRootPart to the ball centre. The hands touch the ball where they
-- can reach it, and the ball never overlaps the body (big balls overhang the player's head).
function Config.ballOffset(diameter: number): number
	local r = diameter / 2
	local dy = HAND_HEIGHT - r
	local handTouch = HAND_REACH + (if math.abs(dy) < r then math.sqrt(r * r - dy * dy) else 0)
	local clearance = BODY_FRONT + (if r <= BODY_HEIGHT then r else math.sqrt(r * r - (r - BODY_HEIGHT) ^ 2))
	return math.max(handTouch, clearance)
end

-- Fresh snow tiles whose centre lies within this distance of the ball centre get collected.
function Config.collectRadius(diameter: number): number
	return math.max(diameter * 0.4, 2.2)
end

return Config
