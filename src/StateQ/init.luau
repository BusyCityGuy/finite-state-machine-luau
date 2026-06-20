--!strict

--[[
	MIT License

	Copyright (c) 2026 BusyCityGuy

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]

-- Version: 0.0.7

--[[
	# What's a finite state machine?
		A Finite State Machine (FSM) provides a way to enforce specific logical flow among a set of States. Given an Event, the FSM responds by looking up the corresponding Transition for that Event in its current State. A Transition is a callback function that is invoked when an Event is given to the FSM, and it returns the next State for the FSM to move to.

		The FSM enforces that Events can only be called when a Transition is defined for that Event in its current State
		by erroring if an Event is called in an invalid state (a state with no Transition defined for that Event).

	# Included features
		The FSM provides 6 signals. Five fire during normal handling of an event; `eventErrored` fires when queued event processing fails.
		These signals, transition callbacks, and state changes are processed in the following order:

		1. Fire `beforeEvent` signal
			* with arguments `eventName`, `beforeState`
		2. Call `transition.beforeAsync()` (required, returns next state)
			* with the VarArgs from `:handle(eventName, transitionArgs...)`
		3. Fire `leavingState` signal
			* with arguments `beforeState, afterState`
			* skipped when the next state equals the current state
		4. Update the current state when it changed
		5. Fire `stateEntered` signal
			* with arguments `afterState, beforeState`
			* skipped when the next state equals the current state
		6. Call `transition.afterAsync()` (if specified)
			* with the VarArgs from `:handle(eventName, transitionArgs...)`
		7. Fire `afterEvent` signal
			* with arguments `eventName, afterState, beforeState`
		8. Fire `finished` signal if next state from `beforeAsync()` was `nil`
			* with argument `beforeState`

		If queued event processing fails, fire `eventErrored` with an `EventError` table
		(machineName, eventName, beforeState, afterState, phase, message, traceback).

		Transitions can be asynchronous, which is supported by queuing each Event submitted via :handle() and processing them in First-In-First-Out (FIFO) order. The next Event starts processing immediately after the previous Event's handler fires `afterEvent`.

		The optional `maxQueueLength` constructor parameter bounds how many Events may be queued at once. When the queue is full,
		further :handle() calls fail with a `queue`-phase EventError. When omitted, the queue is unbounded.

		The FSM can Finish if a Transition does not return a "next state" during an event marked as "canBeFinal".
		In such a case, the FSM will fire the `finished` signal and will error if any further Events are handled.
		A `nil` state means the FSM has Finished.

	# Example usage
		A simple state machine diagram for a light switch may look like this:

			local LightState = {
				On = "On",
				Off = "Off",
			}

			local Event = {
				SwitchOn = "SwitchOn",
				SwitchOff = "SwitchOff",
			}

			local light = StateQ.new(LightState.On, {
				[Event.SwitchOn] = {
					canBeFinal = true,
					from = {
						[LightState.Off] = { -- From state
							beforeAsync = function() -- Transition
								print("Light is transitioning to On")
								for i = 1, 100 do
									-- do some action to increase brightness of a light here
									task.wait()
								end
								return LightState.On -- To next state
							end,
							afterAsync = function()
								print("Light is now On")
							end,
						}
					},
				},
				[Event.SwitchOff] = {
					canBeFinal = true,
					from = {
						[LightState.On] = {
							beforeAsync = function()
								print("Light is transitioning to Off")
								return LightState.Off
							end,
						}
					},
				},
			})

			light:handle(Event.SwitchOff) -- prints "Light is transitioning to Off"
			light:handle(Event.SwitchOn) -- prints "Light is transitioning to On", increases brightness over time, and then prints "Light is now On"
			light:handle(Event.SwitchOn) -- errors asynchronously via `eventErrored` (illegal event for the current state)
--]]

-- This module should be in a folder called Packages that contains other module dependencies.
-- If installed as an rbxm, the Packages folder should be included as the parent of this module already.
-- If installed with Wally, this should already be automatically set up as a descendant of the Packages folder with references to dependencies created.
-- If installed as a submodule, you'll need to edit your project.json file to set the path for this module inside of a Packages folder, and install dependencies there.
local Packages = script.Parent

local Signal = require(script.Modules.Signal)
local ThreadQueue = require(script.Modules.ThreadQueue)
local t = require(Packages.t)

-- These types are added for readability to disambiguate what the string is meant to represent in types
type State = string
local State = t.string

type EventName = string
local EventName = t.string

-- Transitions are sets of functions that handle Events based on the Machine's current state.
-- First, `beforeAsync` returns the next State to transition to, or `nil` when the event is marked `canBeFinal`.
-- Second, an optional `afterAsync` callback executes after the machine finishes transitioning states.
-- Both callbacks can be asynchronous, and the signals described in the header comment will be delayed according to these functions yielding.
export type Transition = {
	beforeAsync: (...any) -> State?,
	afterAsync: ((...any) -> ())?,
}
local Transition = t.strictInterface({
	beforeAsync = t.callback,
	afterAsync = t.optional(t.callback),
})

-- Events choose which Transition to trigger based on the Machine's current State.
-- canBeFinal should only be true if the Transition is allowed to return nil to finish the machine.
-- Otherwise, the Machine will error if the Transition returns nil.
export type Event = {
	canBeFinal: boolean,
	from: {
		[State]: Transition,
	},
}
local Event = t.strictInterface({
	canBeFinal = t.boolean,
	from = t.map(State, Transition),
})

-- EventHandlers fire signals and call transition callbacks as outlined in the header comment
type EventHandler = (enqueueTraceback: string, ...any) -> ()

-- Which step of queued event processing failed.
export type EventErrorPhase = "queue" | "validation" | "beforeAsync" | "afterAsync"

-- Structured error payload fired by `eventErrored`.
export type EventError = {
	machineName: string,
	eventName: EventName,
	beforeState: State?,
	afterState: State?,
	phase: EventErrorPhase,
	message: string,
	traceback: string,
}

-- Runtime type check definitions are up here because it somehow messes up Luau typing if they're put right above the corresponding function.
local newCheck = t.strict(
	t.tuple(State, t.map(EventName, Event), t.optional(t.string), t.optional(t.boolean), t.optional(t.numberPositive))
)
local createEventHandlersCheck = t.strictInterface({
	[EventName] = Event,
})
local checkAfterState = t.strict(t.optional(State))
local queueEventAsyncCheck = t.strict(t.tuple(EventName, Event))
local handleCheck = t.strict(EventName)
local setDebugEnabledCheck = t.strict(t.boolean)

local function errorTraceback(message: string): string
	return debug.traceback(message)
end

local EventErrorPhase = table.freeze({
	queue = "queue" :: "queue",
	validation = "validation" :: "validation",
	beforeAsync = "beforeAsync" :: "beforeAsync",
	afterAsync = "afterAsync" :: "afterAsync",
})

local StateQ = {}
StateQ.EventErrorPhase = EventErrorPhase
StateQ.__index = StateQ
StateQ.__tostring = function(_self)
	return "StateQ"
end

export type ClassType = typeof(setmetatable(
	{} :: {
		-- Public events
		beforeEvent: Signal.ClassType,
		leavingState: Signal.ClassType,
		stateEntered: Signal.ClassType,
		afterEvent: Signal.ClassType,
		finished: Signal.ClassType,
		eventErrored: Signal.ClassType,

		-- Private properties
		_name: string,
		_currentState: State?,
		_eventQueue: ThreadQueue.ClassType,
		_handlersByEventName: { [EventName]: EventHandler },
		_validEventNamesByState: { [State]: { EventName } },
		_isDebugEnabled: boolean,
		_isDestroyed: boolean,
	},
	StateQ
))

local machineNumber = 0

function StateQ.new(
	initialState: State,
	eventsByName: { [EventName]: Event },
	name: string?,
	isDebugEnabled: boolean?,
	maxQueueLength: number?
): ClassType
	newCheck(initialState, eventsByName, name, isDebugEnabled, maxQueueLength)

	machineNumber += 1

	local self = {
		-- Public events
		beforeEvent = Signal.new(),
		leavingState = Signal.new(),
		stateEntered = Signal.new(),
		afterEvent = Signal.new(),
		finished = Signal.new(),
		eventErrored = Signal.new(),

		-- Private properties
		_name = name or `Machine{machineNumber}`,
		_currentState = initialState :: State?,
		_eventQueue = ThreadQueue.new(nil, maxQueueLength),
		_handlersByEventName = {} :: { [EventName]: EventHandler },
		_validEventNamesByState = {} :: { [State]: { EventName } },
		_isDebugEnabled = isDebugEnabled or false,
		_isDestroyed = false,
	}

	setmetatable(self, StateQ)

	self:_createEventHandlers(eventsByName)

	return self
end

function StateQ._createEventHandlers(self: ClassType, eventsByName: { [EventName]: Event })
	createEventHandlersCheck(eventsByName)

	for eventName, event in pairs(eventsByName) do
		self._handlersByEventName[eventName] = function(enqueueTraceback: string, ...: any?)
			local errorInfo = self:_queueEventAsync(eventName, event, enqueueTraceback, ...)
			if errorInfo then
				self:_emitEventError(errorInfo)
			end
		end

		for state, _ in pairs(event.from) do
			self._validEventNamesByState[state] = self._validEventNamesByState[state] or {}
			table.insert(self._validEventNamesByState[state], eventName)
		end
	end
end

function StateQ._queueEventAsync(
	self: ClassType,
	eventName: EventName,
	event: Event,
	enqueueTraceback: string,
	...: any?
): EventError?
	queueEventAsyncCheck(eventName, event)

	local args = { ... }
	local eventError: EventError? = nil

	local function emitEventErrorIfFailed(
		successCondition: any,
		phase: EventErrorPhase,
		beforeState: State?,
		message: string,
		afterState: State?
	)
		if successCondition then
			return
		end
		eventError = self:_buildEventError(eventName, beforeState, phase, message, enqueueTraceback, afterState)
		error(StateQ.formatEventError(eventError :: EventError), 0)
	end

	local submitAsyncSuccess, submitAsyncErrorMessage = self._eventQueue:submitAsync(function()
		if self._isDestroyed then
			return
		end

		emitEventErrorIfFailed(
			self._currentState,
			EventErrorPhase.validation,
			nil,
			`Attempt to process event {eventName} after the state machine already finished`
		)
		local beforeState = self._currentState :: State

		local transition = event.from[beforeState]
		emitEventErrorIfFailed(
			transition,
			EventErrorPhase.validation,
			beforeState,
			`Illegal event {eventName} called during state {beforeState}`
		)

		self.beforeEvent:Fire(eventName, beforeState)

		local beforeAsyncSuccess, beforeAsyncResult = xpcall(transition.beforeAsync, errorTraceback, table.unpack(args))
		emitEventErrorIfFailed(
			beforeAsyncSuccess,
			EventErrorPhase.beforeAsync,
			beforeState,
			tostring(beforeAsyncResult)
		)
		local afterState: State? = beforeAsyncResult
		if self._isDestroyed then
			return
		end

		local checkAfterStateSuccess, checkAfterStateResult = pcall(checkAfterState, afterState)
		emitEventErrorIfFailed(
			checkAfterStateSuccess,
			EventErrorPhase.validation,
			beforeState,
			tostring(checkAfterStateResult)
		)

		self:_debugPrint(`Transitioning from {beforeState} to {afterState}`)

		if afterState ~= beforeState then
			self.leavingState:Fire(beforeState, afterState)
			self._currentState = afterState
			self.stateEntered:Fire(afterState, beforeState)
			self:_debugPrint("Valid events:", self:getValidEvents())
		end

		if transition.afterAsync then
			local afterAsyncSuccess, afterAsyncErrorMessage = xpcall(function(): nil
				transition.afterAsync(table.unpack(args))
				return nil
			end, errorTraceback)
			emitEventErrorIfFailed(
				afterAsyncSuccess,
				EventErrorPhase.afterAsync,
				beforeState,
				tostring(afterAsyncErrorMessage),
				self._currentState
			)
			if self._isDestroyed then
				return
			end
		end

		self.afterEvent:Fire(eventName, afterState, beforeState)

		local isFinished = not afterState

		if isFinished then
			emitEventErrorIfFailed(
				event.canBeFinal,
				EventErrorPhase.validation,
				beforeState,
				`Transition did not return next state during a non-final event {eventName} with state {beforeState}`
			)
			-- State machine finished
			self:_debugPrint("Finished")
			self.finished:Fire(beforeState)
		end
	end)

	if eventError then
		return eventError
	end

	if submitAsyncSuccess == false then
		return self:_buildEventError(
			eventName,
			self._currentState,
			EventErrorPhase.queue,
			submitAsyncErrorMessage or "Unknown queue error",
			enqueueTraceback
		)
	end

	return nil
end

-- VarArgs get passed to the transition callbacks
function StateQ.handle(self: ClassType, eventName: EventName, ...: any?)
	handleCheck(eventName)
	assert(not self._isDestroyed, `Attempt to handle event {eventName} after the state machine was destroyed`)

	local handleEvent = self._handlersByEventName[eventName] :: EventHandler?
	assert(handleEvent, `Invalid event name passed to handle: {eventName}`)

	self:_debugPrint(`Handling {eventName}`)

	local enqueueTraceback = debug.traceback("Queued from:", 2)
	coroutine.wrap(handleEvent :: EventHandler)(enqueueTraceback, ...)
end

function StateQ._buildEventError(
	self: ClassType,
	eventName: EventName,
	beforeState: State?,
	phase: EventErrorPhase,
	message: string,
	traceback: string,
	afterState: State?
): EventError
	return {
		machineName = self._name,
		eventName = eventName,
		beforeState = beforeState,
		afterState = afterState,
		phase = phase,
		message = message,
		traceback = traceback,
	}
end

function StateQ.formatEventError(errorInfo: EventError): string
	local beforeStateLabel = if errorInfo.beforeState then `state {errorInfo.beforeState}` else "state (none)"
	local afterStateLabel = if errorInfo.afterState and errorInfo.afterState ~= errorInfo.beforeState
		then `, now in {errorInfo.afterState}`
		else ""

	return `{errorInfo.machineName}: event {errorInfo.eventName} ({beforeStateLabel}{afterStateLabel}) failed during {errorInfo.phase}:\n\t{errorInfo.message}\n{errorInfo.traceback}`
end

-- Emits an error via the eventErrored signal that occurred while processing a queued event.
-- If nothing is listening, re-raise loudly on a new thread so it isn't silently lost.
function StateQ._emitEventError(self: ClassType, errorInfo: EventError)
	if self.eventErrored:hasAnyConnection() then
		self.eventErrored:Fire(errorInfo)
	else
		-- Casting to any because error's generic typing is messed up with this style of calling
		task.spawn(error, StateQ.formatEventError(errorInfo) :: any)
	end
end

function StateQ._debugPrint(self: ClassType, ...: any?)
	if self._isDebugEnabled then
		print(`{self._name}:`, ...)
	end
end

function StateQ.setDebugEnabled(self: ClassType, enabled: boolean)
	setDebugEnabledCheck(enabled)
	self._isDebugEnabled = enabled
end

function StateQ.getState(self: ClassType)
	return self._currentState
end

function StateQ.getValidEvents(self: ClassType)
	return self._currentState and self._validEventNamesByState[self._currentState] or {}
end

function StateQ.getName(self: ClassType): string
	return self._name
end

function StateQ.isDestroyed(self: ClassType): boolean
	return self._isDestroyed
end

function StateQ.isFinished(self: ClassType): boolean
	return self._currentState == nil
end

function StateQ.isDebugEnabled(self: ClassType): boolean
	return self._isDebugEnabled
end

function StateQ.getMaxQueueLength(self: ClassType): number
	return self._eventQueue:getMaxQueueLength()
end

function StateQ.destroy(self: ClassType)
	self._isDestroyed = true
	self.beforeEvent:DisconnectAll()
	self.leavingState:DisconnectAll()
	self.stateEntered:DisconnectAll()
	self.afterEvent:DisconnectAll()
	self.finished:DisconnectAll()
	self.eventErrored:DisconnectAll()
end

return StateQ
