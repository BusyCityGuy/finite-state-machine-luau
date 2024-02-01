--!strict

--[[
	A lightweight, strongly-typed logger class designed with a minimal set of requirements for the StateMachine project, so it is not feature rich.
	This logger class includes a few features such:
	- A concept of log levels (Debug, Info, Warning, Error): These levels allow for categorizing the importance of the logs.
	- Methods for logging at these levels: Convenient methods for logging at each level.
	- The ability to add handlers: Handlers are functions that process logs. They can be added to the logger to customize its behavior.
	- Handler results (Sink, Continue): Handlers return a result which determines if the logger should proceed with processing the log in other handlers.
	- An assert method: Checks a condition, where failing the assertion invokes the appropriate handlers.

	Handlers are processed from highest minimum level to lowest minimum level. Within a level, they are processed in the
	opposite order that they are added (LIFO). If a handler returns 'Sink', no other handlers will be invoked for that record.

	Adding a default handler pipes non-erroneous records to output via print or warn depending on level,
	and processes errors by throwing them, which will halt the execution of the program unless caught by an error handling mechanism.

	Usage:
		local Logger = require(path.to.Logger)
		local logger = Logger.new("ModuleName")
		logger:addDefaultHandler()
		logger:addHandler(Logger.LogLevel.Error, function(level, name, ...)
			-- Custom error handling that runs before the default handler, and prevents the default handler from handling this
			return Logger.HandlerResult.Sink
		end)
		logger:debug("This is a debug message")
		logger:info("This is an info message")
		logger:warning("This is a warning message")
		logger:error("This is an error message")
		logger:assert(false, "This is an assertion error")

	
--]]

export type LogLevel = "Error" | "Warning" | "Info" | "Debug"
local LogLevel: { [string]: LogLevel } = table.freeze({
	Debug = "Debug" :: "Debug",
	Info = "Info" :: "Info",
	Warning = "Warning" :: "Warning",
	Error = "Error" :: "Error",
})

export type HandlerResult = "Sink" | "Continue"
local HandlerResult: { [string]: HandlerResult } = table.freeze({
	Sink = "Sink" :: "Sink",
	Continue = "Continue" :: "Continue",
})

local orderedLogLevels: { LogLevel } = {
	LogLevel.Error,
	LogLevel.Warning,
	LogLevel.Info,
	LogLevel.Debug,
}

export type Handler = (level: LogLevel, name: string, ...any?) -> HandlerResult?

-- Returning a negative number means levelA is less than levelB, 0 means they are equal,
-- and a positive number means levelA is greater than levelB
local function compareLevels(levelA: LogLevel, levelB: LogLevel): number
	return table.find(orderedLogLevels, levelB) :: number - table.find(orderedLogLevels, levelA) :: number
end

local Logger = {}
Logger.LogLevel = LogLevel
Logger.HandlerResult = HandlerResult
Logger.__index = Logger

export type ClassType = typeof(setmetatable(
	{} :: {
		name: string,
		_handlersByLevel: { [LogLevel]: { Handler } },
		_minimumLevel: LogLevel,
	},
	Logger
))

function Logger.new(name: string, minimumLevel: LogLevel?): ClassType
	local self = {
		name = name,
		_handlersByLevel = {},
		_minimumLevel = minimumLevel or LogLevel.Info,
	}
	setmetatable(self, Logger)

	return self
end

function Logger.addDefaultHandler(self: ClassType)
	self:addHandler(LogLevel.Debug, function(level: LogLevel, name: string, ...: any?)
		if level == LogLevel.Debug or level == LogLevel.Info then
			print(`{name}:{level}:`, ...)
		elseif level == LogLevel.Warning then
			warn(`{name}:{level}:`, ...)
		elseif level == LogLevel.Error then
			error(`{name}:{level}: {...}`, 4)
		else
			error(`Invalid log level: {level}`)
		end

		return HandlerResult.Continue
	end)
end

function Logger.addHandler(self: ClassType, minimumLevel: LogLevel, handler: Handler)
	if not self._handlersByLevel[minimumLevel] then
		self._handlersByLevel[minimumLevel] = {}
	end

	-- Insert at the beginning of the list so newer handlers are processed first (LIFO)
	table.insert(self._handlersByLevel[minimumLevel], 1, handler)
end

function Logger._log(self: ClassType, level: LogLevel, ...: any?)
	if compareLevels(level, self._minimumLevel) < 0 then
		-- Log level is lower than the minimum logger level, so we ignore it
		return
	end

	for _, minimumHandlerLevel: LogLevel in orderedLogLevels do
		if compareLevels(level, minimumHandlerLevel) < 0 then
			-- Log level is lower than the minimum handler level, so we ignore it
			continue
		end

		local handlers = self._handlersByLevel[minimumHandlerLevel]

		if not handlers then
			-- No handlers for this level
			continue
		end

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
	self:_log(LogLevel.Info, ...)
end

function Logger.warning(self: ClassType, ...: any?)
	self:_log(LogLevel.Warning, ...)
end

function Logger.error(self: ClassType, ...: any?)
	self:_log(LogLevel.Error, ...)
end

function Logger.assert(self: ClassType, condition: boolean, message: string?, level: LogLevel?)
	if not condition then
		self:_log(level or LogLevel.Error, message or "Assertion failed")
	end
end

return Logger