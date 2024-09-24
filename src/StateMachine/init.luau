--!strict

--[[
	MIT License

	Copyright (c) 2023 BusyCityGuy

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

-- Version: 0.0.0

--[[
	# What's a finite state machine?
		A Finite State Machine (FSM) provides a way to enforce specific logical flow among a set of States. Given an Event, the FSM responds by looking up the corresponding Transition for that Event in its current State. A Transition is a callback function that is invoked when an Event is given to the FSM, and it returns the next State for the FSM to move to.

		The FSM enforces that Events can only be called when a Transition is defined for that Event in its current State
		by erroring if an Event is called in an invalid state (a state with no Transition defined for that Event).

	# Included features
		The FSM provides 5 signals that can be listened to during handling of an event.
		These signals, transition callbacks, and state changes are processed in the following order:

		1. Fire `beforeEvent` signal
			* with arguments `eventName`, `beforeState`
		2. Call `transition.beforeAsync()` (required, returns next state)
			* with the VarArgs from `:handle(eventName, transitionArgs...)`
		3. Fire `leavingState` signal
			* with arguments `beforeState, afterState`
		4. Update `_currentState` to next state
		5. Fire `stateEntered` signal
			* with arguments `afterState, beforeState`
		6. Call `transition.afterAsync()` (if specified)
			* with the VarArgs from `:handle(eventName, transitionArgs...)`
		7. Fire `afterEvent` signal
			* with arguments `eventName, afterState, beforeState`
		8. Fire `finished` signal if next state from `beforeAsync()` was `nil`
			* with argument `beforeState`

		Transitions can be asynchronous, which is supported by queuing each Event submitted via :handle() and processing them in First-In-First-Out (FIFO) order. The next Event starts processing immediately after the previous Event's handler fires `afterEvent`.

		The FSM can Finish if a Transition does not return a "next state" during an event marked as "canBeFinal".
		In such a case, the FSM will fire a `finished` event and will error if any further Events are handled.
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

			local light = StateMachine.new(LightState.On, {
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
			light:handle(Event.SwitchOn) -- errors "Illegal event `SwitchOn` called during state `On`" with a stack trace
--]]

local Logger = require(script.Modules.Logger)
local Signal = require(script.Modules.Signal)
local ThreadQueue = require(script.Modules.ThreadQueue)
local t = require(script.Dependencies.t)

-- These types are added for readability to disambiguate what the string is meant to represent in types
type State = string
local State = t.string

type EventName = string
local EventName = t.string

-- Transitions are sets of functions that handle Events based on the Machine's current state.
-- First, the `before` callback executes which returns the next State to transition to, or `nil` if the machine is meant to finish.
-- Second, an optional `after` callback can be defined that that executes after the machine finishes transitioning states.
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
type EventHandler = (...any) -> ()

local DEFAULT_LOG_LEVEL: Logger.LogLevel = Logger.LogLevel.Info

-- Runtime type check definitions are up here because it somehow messes up Luau typing if they're put right above the corresponding function.
local newCheck =
	t.strict(t.tuple(State, t.map(EventName, Event), t.optional(t.string), t.optional(t.valueOf(Logger.LogLevel))))
local createEventHandlersCheck = t.strictInterface({
	[EventName] = Event,
})
local checkAfterState = t.strict(t.optional(State))
local queueEventAsyncCheck = t.strict(t.tuple(EventName, Event))
local handleCheck = t.strict(EventName)

local StateMachine = {}
StateMachine.Logger = Logger
StateMachine.__index = StateMachine
StateMachine.__tostring = function(_self)
	return "StateMachine"
end

export type ClassType = typeof(setmetatable(
	{} :: {
		-- Public events
		beforeEvent: Signal.ClassType,
		leavingState: Signal.ClassType,
		stateEntered: Signal.ClassType,
		afterEvent: Signal.ClassType,
		finished: Signal.ClassType,

		-- Private properties
		_currentState: State?,
		_eventQueue: ThreadQueue.ClassType,
		_handlersByEventName: { [EventName]: EventHandler },
		_validEventNamesByState: { [State]: { EventName } },
		_logger: Logger.ClassType,
		_isDestroyed: boolean,
	},
	StateMachine
))

local machineNumber = 0

function StateMachine.new(
	initialState: State,
	eventsByName: { [EventName]: Event },
	name: string?,
	logLevel: Logger.LogLevel?
): ClassType
	newCheck(initialState, eventsByName, name, logLevel)

	machineNumber += 1
	local defaultName = `Machine{machineNumber}`
	name = name or `Machine{machineNumber}`

	local logger = Logger.new(name or defaultName, logLevel or DEFAULT_LOG_LEVEL)
	logger:addDefaultHandler()

	local self = {
		-- Public events
		beforeEvent = Signal.new(),
		leavingState = Signal.new(),
		stateEntered = Signal.new(),
		afterEvent = Signal.new(),
		finished = Signal.new(),

		-- Private properties
		_currentState = initialState :: State?,
		_eventQueue = ThreadQueue.new(),
		_handlersByEventName = {} :: { [EventName]: EventHandler },
		_validEventNamesByState = {} :: { [State]: { EventName } },
		_logger = logger,
		_isDestroyed = false,
	}

	setmetatable(self, StateMachine)

	self:_createEventHandlers(eventsByName)

	return self
end

function StateMachine._createEventHandlers(self: ClassType, eventsByName: { [EventName]: Event })
	self:getLogger():wrap(createEventHandlersCheck, eventsByName)

	for eventName, event in pairs(eventsByName) do
		self._handlersByEventName[eventName] = function(...: any?)
			local success, errorMessage = self:_queueEventAsync(eventName, event, ...)
			self:getLogger():assert(success, `Failed to queue event {eventName}:\n\t{errorMessage}`)
		end

		for state, _ in pairs(event.from) do
			self._validEventNamesByState[state] = self._validEventNamesByState[state] or {}
			table.insert(self._validEventNamesByState[state], eventName)
		end
	end
end

function StateMachine._queueEventAsync(self: ClassType, eventName: EventName, event: Event, ...: any?)
	self:getLogger():wrap(queueEventAsyncCheck, eventName, event)

	local args = { ... }

	local success, errorMessage = self._eventQueue:submitAsync(function()
		if self._isDestroyed then
			return
		end

		assert(self._currentState, `Attempt to process event {eventName} after the state machine already finished`)
		local beforeState = self._currentState :: State

		local transition = event.from[beforeState]
		assert(transition, `Illegal event {eventName} called during state {beforeState}`)

		self.beforeEvent:Fire(eventName, beforeState)
		local afterState = transition.beforeAsync(table.unpack(args))
		if self._isDestroyed then
			return
		end

		self:getLogger():wrap(checkAfterState, afterState)

		self:getLogger():debug(`Transitioning from {beforeState} to {afterState}`)

		if afterState ~= beforeState then
			self.leavingState:Fire(beforeState, afterState)
			self._currentState = afterState
			self.stateEntered:Fire(afterState, beforeState)
			self:getLogger():debug("Valid events:", self:getValidEvents())
		end

		if transition.afterAsync then
			transition.afterAsync(table.unpack(args))
			if self._isDestroyed then
				return
			end
		end

		self.afterEvent:Fire(eventName, afterState, beforeState)

		local isFinished = not afterState

		if isFinished then
			self:getLogger():assert(
				event.canBeFinal,
				`Transition did not return next state during a non-final event {eventName} with state {beforeState}`
			)
			-- State machine finished
			self:getLogger():debug("Finished")
			self.finished:Fire(beforeState)
		end
	end)

	return success, errorMessage
end

-- VarArgs get passed to the transition callbacks
function StateMachine.handle(self: ClassType, eventName: EventName, ...: any?)
	self:getLogger():wrap(handleCheck, eventName)
	self:getLogger()
		:assert(not self._isDestroyed, `Attempt to handle event {eventName} after the state machine was destroyed`)

	local handleEvent = self._handlersByEventName[eventName] :: EventHandler?
	self:getLogger():assert(handleEvent, `Invalid event name passed to handle: {eventName}`)

	self:getLogger():debug(`Handling {eventName}`)
	coroutine.wrap(handleEvent :: EventHandler)(...)
end

function StateMachine.getLogger(self: ClassType): Logger.ClassType
	return self._logger
end

function StateMachine.getState(self: ClassType)
	return self._currentState
end

function StateMachine.getValidEvents(self: ClassType)
	return self._currentState and self._validEventNamesByState[self._currentState] or {}
end

function StateMachine.destroy(self: ClassType)
	self._isDestroyed = true
	self.beforeEvent:DisconnectAll()
	self.leavingState:DisconnectAll()
	self.stateEntered:DisconnectAll()
	self.afterEvent:DisconnectAll()
	self.finished:DisconnectAll()
end

return StateMachine
