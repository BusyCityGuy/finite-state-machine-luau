--!strict

--[[
	A lightweight, strictly typed logger class designed with a minimal set of requirements for the StateQ project, so it is not feature rich.
	This logger class includes a few features such:
	- A concept of log levels (Debug, Info, Warning, Error): These levels allow for categorizing the importance of the logs.
	- Methods for logging at these levels: Convenient methods for logging at each level.
	- The ability to add handlers: Handlers are functions that process logs. They can be added to the logger to customize its behavior.
	- Handler results (Sink, Continue): Handlers return a result which determines if the logger should proceed with processing the log in other handlers.
	- An assert method: Checks a condition, where failing the assertion invokes the appropriate handlers.
	- A wrap method: Wraps a callback in pcall, invoking the appropriate handlers if an error occurs.

	Handlers are processed from highest minimum level to lowest minimum level. Within a level, they are processed in the
	opposite order that they are added (LIFO). If a handler returns 'Sink', no other handlers will be invoked for that record.

	Adding a default handler pipes non-erroneous records to output via print or warn depending on level,
	and processes errors by throwing them, which will halt the execution of the program unless caught by an error handling mechanism.

	Usage:
		local Logger = require(path.to.Logger)
		local logger = Logger.new("ModuleName", Logger.LogLevel.Info)
		logger:addDefaultHandler()
		logger:addHandler(Logger.LogLevel.Error, function(level, name, ...)
			-- Custom error handling that runs before the default handler, and prevents the default handler from handling this
			print("Custom error handler:", name, level, ...)
			return Logger.HandlerResult.Sink
		end)
		logger:debug("This is a debug message") -- Doesn't get handled because logger level is set to Info
		logger:info("This is an info message")
		logger:warning("This is a warning message")
		logger:error("This is an error message")
		logger:assert(false, "This is an assertion error")
		logger:wrap(function()
			error("This is an error thrown from a wrapped function")
		end)

	A primary purpose of this class existing is to be able to check for errors from within tests. The StateQ queues events,
	starting a new thread to process them, which means errors that occur are not propagated to the main thread and can't be tested for.
	This logger class allows for the testing of errors by adding a handler for errors, and then checking for those errors in tests.
--]]

export type LogLevel = "Error" | "Warning" | "Info" | "Debug"
local LogLevel: { [string]: LogLevel } = {
	Debug = "Debug" :: "Debug",
	Info = "Info" :: "Info",
	Warning = "Warning" :: "Warning",
	Error = "Error" :: "Error",
}
table.freeze(LogLevel)

export type HandlerResult = "Sink" | "Continue"
local HandlerResult: { [string]: HandlerResult } = {
	Sink = "Sink" :: "Sink",
	Continue = "Continue" :: "Continue",
}
table.freeze(HandlerResult)

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
	local indexA = table.find(orderedLogLevels, levelA)
	assert(indexA, `Invalid log level: {levelA}`)

	local indexB = table.find(orderedLogLevels, levelB)
	assert(indexB, `Invalid log level: {levelB}`)
	return indexB - indexA
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

function Logger.assert(self: ClassType, condition: any, message: string?, level: LogLevel?)
	if not condition then
		self:_log(level or LogLevel.Error, message or "Assertion failed")
	end
end

function Logger.wrap(self: ClassType, callback: (...any) -> ...any, ...: any?)
	-- FIXME: Return all results, not just the first one
	local success, result = pcall(callback, ...)
	-- Not using self:assert to ensure the stack trace level is consistent for error tracebacks
	if not success then
		self:_log(LogLevel.Error, result)
	end
	return success, result
end

return Logger
