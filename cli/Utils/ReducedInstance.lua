--!strict
local roblox = require("@lune/roblox")

local ReducedInstance = {}
ReducedInstance._cache = {}

-- this is so lune's Instance would be one reference, at least for now.
function ReducedInstance.once(instance: roblox.Instance): roblox.Instance
	if not instance then
		error("Instance is nil")
	end
	local fullName = instance:GetFullName()
	if ReducedInstance._cache[fullName] then
		return ReducedInstance._cache[fullName]
	end
	local self = setmetatable({
		instance = instance,
	}, {
		__index = function(self, key): any?
			local value = self.instance[key]
			if type(value) == "function" then
				if key == "FindFirstChild" then
					return function(self, ...): roblox.Instance?
						local child = self.instance:FindFirstChild(...)
						if child then
							return ReducedInstance.once(child :: roblox.Instance)
						end
						return
					end
				elseif key == "WaitForChild" then
					return function(self, ...)
						return ReducedInstance.once(self.instance:WaitForChild(...) :: roblox.Instance)
					end
				else
					return function(self, ...)
						return value(self.instance, ...)
					end
				end
			elseif typeof(value) == "Instance" then
				return ReducedInstance.once((value :: never) :: roblox.Instance)
			end

			return value
		end,
		__newindex = function(self, key, value)
			self.instance[key] = value
		end,
		__metatable = false,
	})

	ReducedInstance._cache[fullName] = self

	return (self :: any) :: roblox.Instance
end

return ReducedInstance
