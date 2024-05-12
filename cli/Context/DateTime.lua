--!strict
local datetime = require("@lune/datetime")

local DateTime = setmetatable({
	now = function(module)
		local now = datetime.now()
		return setmetatable({
			UnixTimestampMillis = now.unixTimestampMillis,
			UnixTimestamp = now.unixTimestamp,
		}, {__index = now})
	end
}, {__index = datetime})

return DateTime