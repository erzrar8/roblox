local Hud = require(script.Hud)
local SnowFall = require(script.SnowFall)
local SnowballVisuals = require(script.SnowballVisuals)
local ZoneWatcher = require(script.ZoneWatcher)

SnowFall.start()
SnowballVisuals.start()
ZoneWatcher.start()
-- Last: it waits for the server's remotes.
Hud.start()
