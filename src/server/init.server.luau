local EconomyService = require(script.EconomyService)
local MapCleanup = require(script.MapCleanup)
local SnowballService = require(script.SnowballService)

MapCleanup.run()
EconomyService.start()
SnowballService.start()
