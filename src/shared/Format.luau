--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

-- 950 -> "950", 1234 -> "1.23K", 45600 -> "45.6K", 7890000 -> "7.89M". Rounds down, never up.
function Format.short(value: number): string
	local n = math.max(0, value)
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text
	if n >= 100 then
		text = tostring(math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100) / 100)
	end
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "%.?0+$", "")
	end
	return text .. SUFFIXES[index]
end

-- 1.25 -> "x1.25", 1.5 -> "x1.5", 2 -> "x2"
function Format.multiplier(value: number): string
	local text = string.format("%.2f", math.floor(value * 100 + 0.5) / 100)
	text = string.gsub(text, "%.?0+$", "")
	return "x" .. text
end

return Format
