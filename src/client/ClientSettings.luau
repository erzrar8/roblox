--!strict
-- The player's choices from the Settings menu. They last for this session only: the game does not
-- save anything between sessions yet.
local ClientSettings = {}

export type Id = "Snowfall" | "TaskTracker"

local values: { [string]: boolean } = {
	Snowfall = true,
	TaskTracker = true,
}
local listeners: { [string]: { (boolean) -> () } } = {}

function ClientSettings.get(id: Id): boolean
	return values[id]
end

function ClientSettings.set(id: Id, value: boolean)
	if values[id] == value then
		return
	end
	values[id] = value
	local list = listeners[id]
	if list then
		for _, listener in list do
			task.spawn(listener, value)
		end
	end
end

function ClientSettings.onChanged(id: Id, listener: (boolean) -> ())
	listeners[id] = listeners[id] or {}
	table.insert(listeners[id], listener)
end

return ClientSettings
