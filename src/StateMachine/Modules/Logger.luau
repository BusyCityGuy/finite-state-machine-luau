--!strict

--[[
	TODO: Write header comment and generally document the behavior of this logger
--]]

export type LogLevel = {
	Debug: number,
	Info: number,
	Warning: number,
	Error: number,
}

export type Handler = (level: LogLevel, name: string, ...any?) -> ()

local LogLevelNameByValue: { [number]: LogLevel } = table.freeze({
	[10] = "Debug",
	[20] = "Info",
	[30] = "Warning",
	[40] = "Error",
})

local LogLevel: { [LogLevel]: number } = table.freeze({
	Debug = 10,
	Info = 20,
	Warning = 30,
	Error = 40,
})

export type HandlerResult = {
	Sink: "Sink",
	Continue: "Continue",
}
local HandlerResult: HandlerResult = table.freeze({
	Sink = "Sink",
	Continue = "Continue",
})

export type ClassType = typeof(setmetatable(
	{} :: {
		name: string,
		_handlers: { [LogLevel]: { Handler } },
	},
	Logger
))

local Logger = {}
Logger.LogLevel = LogLevel
Logger.LogLevelNameByValue = LogLevelNameByValue
Logger.HandlerResult = HandlerResult
Logger.__index = Logger

function Logger.new(name: string, level: LogLevel?): ClassType
	local self = {
		name = name,
		_handlersByLevel = {},
		_sortedHandlerLevels = {},
		_level = level or LogLevel.Info,
	}
	setmetatable(self, Logger)

	return self
end

function Logger.addDefaultHandler(self: ClassType)
	self:addHandler(0, function(level: LogLevel, name: string, ...: any?)
		local levelName = LogLevelNameByValue[level] or level
		if level < LogLevel.Warning then
			print(`{name}:{levelName}:`, ...)
		elseif level < LogLevel.Error then
			warn(`{name}:{levelName}:`, ...)
		else
			error(`{name}:{levelName}: {...}`, 4)
		end
	end)
end

function Logger.addHandler(self: ClassType, level: LogLevel, handler: Handler)
	if not self._handlersByLevel[level] then
		self._handlersByLevel[level] = {}
	end

	table.insert(self._handlersByLevel[level], 1, handler)

	local handlerLevels = {}
	for handlerLevel in self._handlersByLevel do
		if handlerLevel > level then
			continue
		end

		table.insert(handlerLevels, handlerLevel)
	end

	table.sort(handlerLevels, function(a: LogLevel, b: LogLevel)
		return a > b
	end)

	self._sortedHandlerLevels = handlerLevels
end

function Logger._log(self: ClassType, level: LogLevel, ...: any?)
	if level < self._level then
		return
	end

	local filteredHandlerLevels = {}

	for handlerLevel in self._handlersByLevel do
		if handlerLevel > level then
			continue
		end

		table.insert(filteredHandlerLevels, handlerLevel)
	end

	for _, handlerLevel in self._sortedHandlerLevels do
		local handlers = self._handlersByLevel[handlerLevel]
		for _, handler in handlers do
			local result = handler(level, self.name, ...)
			if result == HandlerResult.Sink then
				return
			end
		end
	end
end

function Logger.log(self: ClassType, level: LogLevel, ...: any?)
	self:_log(level, ...)
end

function Logger.debug(self: ClassType, ...: any?)
	self:_log(LogLevel.Debug, ...)
end

function Logger.info(self: ClassType, ...: any?)
	self:l_logog(LogLevel.Info, ...)
end

function Logger.warning(self: ClassType, ...: any?)
	self:_log(LogLevel.Warning, ...)
end

function Logger.error(self: ClassType, ...: any?)
	self:_log(LogLevel.Error, ...)
end

function Logger.assert(self: ClassType, condition: boolean, message: string?, level: LogLevel?)
	if not condition then
		level = level or LogLevel.Error
		self:_log(level, message)
	end
end

return Logger
