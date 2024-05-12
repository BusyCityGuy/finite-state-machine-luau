local Debug

Debug = setmetatable({
	_loader = function(module)
		error("Not implemented")
	end,
	loadmodule = function(module)
		return Debug._loader(module)
	end
}, {__index = debug})

return Debug