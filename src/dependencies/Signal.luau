--!strict

--------------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- API:                                                                       --
--   local Signal = require(THIS MODULE)                                      --
--   local sig = Signal.new()                                                 --
--   local connection = sig:Connect(function(arg1, arg2, ...) ... end)        --
--   sig:Fire(arg1, arg2, ...)                                                --
--   connection:Disconnect()                                                  --
--   sig:DisconnectAll()                                                      --
--   local arg1, arg2, ... = sig:Wait()                                       --
--                                                                            --
-- Licence:                                                                   --
--   Licenced under the MIT licence.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--------------------------------------------------------------------------------
-- This file has been modified to add Luau typing support

type Callback = (...any?) -> ...any?

-- The currently idle thread to run the next handler on
local freeRunnerThread: thread? = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread(...)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

-- Connection class
local Connection = {}
Connection.__index = Connection

export type SignalConnection = typeof(setmetatable(
	{} :: {
		_connected: boolean,
		_signal: ClassType,
		_fn: Callback,
		_next: SignalConnection?,
	},
	Connection
))

function Connection.new(signal: ClassType, fn: Callback): SignalConnection
	local self = {
		_connected = true,
		_signal = signal,
		_fn = fn,
		_next = nil,
	}

	setmetatable(self, Connection)

	return self
end

function Connection.Disconnect(self: SignalConnection)
	assert(self._connected, "Can't disconnect a connection twice.")
	self._connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self._signal._handlerListHead and (self._signal._handlerListHead :: SignalConnection) == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

-- Signal class
local Signal = {}
Signal.__index = Signal

export type ClassType = typeof(setmetatable({} :: {
	_handlerListHead: SignalConnection?,
}, Signal))

function Signal.new(): ClassType
	return setmetatable({
		_handlerListHead = nil,
	}, Signal)
end

function Signal.Connect(self: ClassType, fn: Callback): SignalConnection
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead :: SignalConnection

		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
function Signal.DisconnectAll(self: ClassType)
	self._handlerListHead = nil
end

-- Signal:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
function Signal.Fire(self: ClassType, ...: any?)
	local item = self._handlerListHead
	while item do
		if item._connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
			end
			task.spawn(freeRunnerThread :: thread, item._fn, ...)
		end
		item = item._next
	end
end

-- Implement Signal:Wait() in terms of a temporary connection using
-- a Signal:Connect() which disconnects itself.
function Signal.Wait(self: ClassType)
	local waitingCoroutine = coroutine.running()
	local cn: SignalConnection
	cn = self:Connect(function(...: any?)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

return Signal
