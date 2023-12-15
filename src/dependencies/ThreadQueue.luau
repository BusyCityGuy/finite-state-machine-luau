--!strict

--[[
	ThreadQueue is a task scheduler and rate limiter that allows callbacks to be queued to be executed, yielding the requesting thread
	until the callback has returned.

	Provides similar functionality to the NodeJS module Bottleneck (https://www.npmjs.com/package/bottleneck) however, it exposes
	its scheduling functionality through coroutines rather than promises.
--]]

local ThreadQueue = {}
ThreadQueue.__index = ThreadQueue

export type ClassType = typeof(setmetatable(
	{} :: {
		_queue: { QueueEntry },
		_queueRunning: boolean,
		_timeBetween: number,
		_maxQueueLength: number,
		_enableConcurrency: boolean,
	},
	ThreadQueue
))

type Callback = (...any) -> ...any

type QueueEntry = {
	thread: thread,
	callback: Callback,
}

function ThreadQueue.new(timeBetween: number?, maxQueueLength: number?, enableConcurrency: boolean?): ClassType
	local self = {
		_queue = {},
		_queueRunning = false,
		_timeBetween = (timeBetween or 0),
		_maxQueueLength = (maxQueueLength or math.huge),
		_enableConcurrency = enableConcurrency and true or false,
	}
	setmetatable(self, ThreadQueue)

	return self
end

function ThreadQueue.submitAsync(self: ClassType, callback: Callback)
	if #self._queue > self._maxQueueLength then
		return false, string.format("Queue is at capacity (%i)", self._maxQueueLength)
	end

	local queueEntry: QueueEntry = {
		thread = coroutine.running(),
		callback = callback,
	}

	table.insert(self._queue, queueEntry)

	self:_startQueue()

	return coroutine.yield()
end

function ThreadQueue.getLength(self: ClassType): number
	return #self._queue
end

function ThreadQueue.skipToLastEnqueued(self: ClassType)
	-- This method will not skip currently executing requests, but will remove
	-- all pending requests from the queue aside from the most recently enqueued
	if #self._queue > 1 then
		local lastEnqueuedEntry = self._queue[#self._queue]
		self._queue = { lastEnqueuedEntry }
	end
end

function ThreadQueue._startQueue(self: ClassType)
	-- Wait for the next resumption cycle, so the requesting thread has time to yield first
	task.defer(function()
		if self._queueRunning then
			return
		end
		self._queueRunning = true

		while #self._queue > 0 do
			self:_popQueueAsync()

			if self._timeBetween > 0 then
				task.wait(self._timeBetween)
			end
		end

		self._queueRunning = false
	end)
end

function ThreadQueue._popQueueAsync(self: ClassType)
	local entry = table.remove(self._queue, 1) :: QueueEntry

	local function execute()
		-- This callback can yield. Note the callback is called synchronously on this thread.
		-- The task.spawn is used to resume the calling thread with the pcall'd results of the callback.
		task.spawn(entry.thread, pcall(entry.callback))
	end

	-- If concurrency is enabled, we do not want to yield the queue while we wait for the callback to return
	if self._enableConcurrency then
		-- Use spawn to call execute so entry.callback doesn't block us from proceeding
		task.spawn(execute)
	else
		execute()
	end
end

return ThreadQueue
