-- local Signal = require(script.Dependencies.Signal)
-- local ThreadQueue = require(script.Dependencies.ThreadQueue)

-- -- These types are added for readability to disambiguate what the string is meant to represent in types
-- type State = string
-- type EventName = string

-- -- Transitions are sets of functions that handle Events based on the Machine's current state.
-- -- First, the `before` callback executes which returns the next State to transition to, or `nil` if the machine is meant to finish.
-- -- Second, an optional `after` callback can be defined that that executes after the machine finishes transitioning states.
-- -- Both callbacks can be asynchronous, and the signals described in the header comment will be delayed according to these functions yielding.
-- export type Transition = {
-- 	beforeAsync: (...any) -> State?,
-- 	afterAsync: ((...any) -> ())?,
-- }

-- -- Events choose which Transition to trigger based on the Machine's current State.
-- -- canBeFinal should only be true if the Transition is allowed to return nil to finish the machine.
-- -- Otherwise, the Machine will error if the Transition returns nil.
-- export type Event = {
-- 	canBeFinal: boolean,
-- 	from: {
-- 		[State]: Transition,
-- 	},
-- }

-- -- EventHandlers fire signals and call transition callbacks as outlined in the header comment
-- type EventHandler = (...any) -> ()

-- local StateMachine = {}
-- StateMachine.__index = StateMachine

-- export type ClassType = typeof(setmetatable(
-- 	{} :: {
-- 		-- Public events
-- 		beforeEvent: Signal.ClassType,
-- 		leavingState: Signal.ClassType,
-- 		stateEntered: Signal.ClassType,
-- 		afterEvent: Signal.ClassType,
-- 		finished: Signal.ClassType,

-- 		-- Private properties
-- 		_currentState: State?,
-- 		_eventQueue: ThreadQueue.ClassType,
-- 		_handlersByEventName: { [EventName]: EventHandler },
-- 		_validEventNamesByState: { [State]: { EventName } },
-- 		_isDebugEnabled: boolean,
-- 		_isDestroyed: boolean,
-- 	},
-- 	StateMachine
-- ))

-- function StateMachine.new(initialState: State, eventsByName: { [EventName]: Event }): ClassType
-- 	assert(initialState, "Missing initial state to new state machine")
-- 	assert(eventsByName, "Missing events to new state machine")

-- 	local self = {
-- 		-- Public events
-- 		beforeEvent = Signal.new(),
-- 		leavingState = Signal.new(),
-- 		stateEntered = Signal.new(),
-- 		afterEvent = Signal.new(),
-- 		finished = Signal.new(),

-- 		-- Private properties
-- 		_currentState = initialState :: State?,
-- 		_eventQueue = ThreadQueue.new(),
-- 		_handlersByEventName = {} :: { [EventName]: EventHandler },
-- 		_validEventNamesByState = {} :: { [State]: { EventName } },
-- 		_isDebugEnabled = false,
-- 		_isDestroyed = false,
-- 	}

-- 	setmetatable(self, StateMachine)

-- 	self:_createEventHandlers(eventsByName)

-- 	return self
-- end

-- function StateMachine._createEventHandlers(self: ClassType, eventsByName: { [EventName]: Event })
-- 	for eventName, event in pairs(eventsByName) do
-- 		self._handlersByEventName[eventName] = function(...: any?)
-- 			local success, errorMessage = self:_queueEventAsync(eventName, event, ...)
-- 			if not success then
-- 				error(`Failed to queue event {eventName}: {errorMessage}`)
-- 			end
-- 		end

-- 		for state, _ in pairs(event.from) do
-- 			self._validEventNamesByState[state] = self._validEventNamesByState[state] or {}
-- 			table.insert(self._validEventNamesByState[state], eventName)
-- 		end
-- 	end
-- end

-- function StateMachine._queueEventAsync(self: ClassType, eventName: EventName, event: Event, ...: any?)
-- 	local args = { ... }

-- 	local success, errorMessage = self._eventQueue:submitAsync(function()
-- 		if self._isDestroyed then
-- 			return
-- 		end

-- 		assert(self._currentState, `Attempt to process event {eventName} after the state machine already finished`)
-- 		local beforeState = self._currentState :: State

-- 		local transition = event.from[beforeState]
-- 		assert(transition, `Illegal event {eventName} called during state {beforeState}`)

-- 		self[BEFORE_EVENT_SIGNAL]:Fire(eventName, beforeState)
-- 		local afterState = transition.beforeAsync(table.unpack(args))
-- 		if self._isDestroyed then
-- 			return
-- 		end

-- 		self:_log(`Transitioning from {beforeState} to {afterState}`)

-- 		if afterState ~= beforeState then
-- 			self[LEAVING_STATE_SIGNAL]:Fire(beforeState, afterState)
-- 			self._currentState = afterState
-- 			self[STATE_ENTERED_SIGNAL]:Fire(afterState, beforeState)
-- 			self:_log("Valid events:", self:getValidEvents())
-- 		end

-- 		if transition.afterAsync then
-- 			transition.afterAsync(table.unpack(args))
-- 			if self._isDestroyed then
-- 				return
-- 			end
-- 		end

-- 		self[AFTER_EVENT_SIGNAL]:Fire(eventName, afterState, beforeState)

-- 		local isFinished = not afterState

-- 		if isFinished then
-- 			assert(
-- 				event.canBeFinal,
-- 				`Transition did not return next state during a non-final event {eventName} with state {beforeState}`
-- 			)
-- 			-- State machine finished
-- 			self:_log("Finished")
-- 			self[FINISHED_SIGNAL]:Fire(beforeState)
-- 		end
-- 	end)

-- 	if not success then
-- 		error(errorMessage, 3)
-- 	end
-- end

-- -- VarArgs get passed to the transition callbacks
-- function StateMachine.handle(self: ClassType, eventName: EventName, ...: any?)
-- 	assert(not self._isDestroyed, `Attempt to handle event {eventName} after the state machine was destroyed`)

-- 	local handleEvent = self._handlersByEventName[eventName] :: EventHandler?
-- 	assert(handleEvent, `Invalid event name passed to handle: {eventName}`)

-- 	self:_log(`Handling {eventName}`)
-- 	coroutine.wrap(handleEvent)(...)
-- end

-- function StateMachine.getState(self: ClassType)
-- 	return self._currentState
-- end

-- function StateMachine.getValidEvents(self: ClassType)
-- 	return self._currentState and self._validEventNamesByState[self._currentState] or {}
-- end

-- function StateMachine.setDebugEnabled(self: ClassType, isEnabled: boolean)
-- 	self._isDebugEnabled = isEnabled
-- end

-- function StateMachine._log(self: ClassType, ...: any)
-- 	if self._isDebugEnabled then
-- 		print(...)
-- 	end
-- end

-- function StateMachine.destroy(self: ClassType)
-- 	self._isDestroyed = true
-- 	self[BEFORE_EVENT_SIGNAL]:DisconnectAll()
-- 	self[LEAVING_STATE_SIGNAL]:DisconnectAll()
-- 	self[STATE_ENTERED_SIGNAL]:DisconnectAll()
-- 	self[AFTER_EVENT_SIGNAL]:DisconnectAll()
-- 	self[FINISHED_SIGNAL]:DisconnectAll()
-- end

-- return function()
--     local Greeter = require(script.Parent.Greeter)

--     describe("greet", function()
--         it("should include the customary English greeting", function()
--             local greeting = Greeter:greet("X")
--             expect(greeting:match("Hello")).to.be.ok()
--         end)

--         it("should include the person being greeted", function()
--             local greeting = Greeter:greet("Joe")
--             expect(greeting:match("Joe")).to.be.ok()
--         end)
--     end)
-- end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

-- States
local X_STATE = "X_STATE"
local Y_STATE = "Y_STATE"
local FINISH_STATE = nil

-- Events
local TO_X_EVENT = "TO_X_EVENT"
local TO_Y_EVENT = "TO_Y_EVENT"
local FINISH_EVENT = "FINISH_EVENT"

-- Signals
local BEFORE_EVENT_SIGNAL = "beforeEvent"
local LEAVING_STATE_SIGNAL = "leavingState"
local STATE_ENTERED_SIGNAL = "stateEntered"
local AFTER_EVENT_SIGNAL = "afterEvent"
local FINISHED_SIGNAL = "finished"
local ORDERED_SIGNALS = {
	BEFORE_EVENT_SIGNAL,
	LEAVING_STATE_SIGNAL,
	STATE_ENTERED_SIGNAL,
	AFTER_EVENT_SIGNAL,
	FINISHED_SIGNAL,
}

-- Transition handlers
local function to(state: string)
	return function()
		return state
	end
end
local TO_X_HANDLER = to(X_STATE)
local TO_Y_HANDLER = to(Y_STATE)
local FINISH_HANDLER = to(FINISH_STATE)

local function plural(count: number)
	return if count == 1 then "" else "s"
end

return function()
	local StateMachine = require(ReplicatedStorage.Source.StateMachine)
	local Freeze = require(TestService.Dependencies.Freeze)

	-- Shortening things is generally bad practice, but this greatly improves readability of tests
	local Dict = Freeze.Dictionary

	-- Done
	describe("new", function()
		it("should return a new state machine", function()
			local initialState = X_STATE
			local eventsByName = {
				[TO_X_EVENT] = {
					canBeFinal = true,
					from = {
						[X_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine1 = StateMachine.new(initialState, eventsByName)
			local stateMachine2 = StateMachine.new(initialState, eventsByName)

			expect(stateMachine1).to.be.a("table")
			expect(stateMachine2).to.be.a("table")
			expect(getmetatable(stateMachine1)).to.be.a("table")
			expect(getmetatable(stateMachine1)).to.equal(getmetatable(stateMachine2))
			expect(stateMachine1).never.to.equal(stateMachine2)
		end)

		it("should set initial state", function()
			local initialState = X_STATE
			local eventsByName = {
				[TO_X_EVENT] = {
					canBeFinal = true,
					from = {
						[X_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)
			expect(stateMachine._currentState).to.equal(initialState)
		end)

		it("should set valid event names by state", function()
			local eventsByName = {
				[TO_Y_EVENT] = {
					canBeFinal = false,
					from = {
						[X_STATE] = {
							beforeAsync = TO_Y_HANDLER,
						},
						[Y_STATE] = {
							beforeAsync = TO_Y_HANDLER,
						},
					},
				},
				[TO_X_EVENT] = {
					canBeFinal = false,
					from = {
						[Y_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine = StateMachine.new(X_STATE, eventsByName)
			local validEventNamesFromX = stateMachine._validEventNamesByState[X_STATE]
			local validEventNamesFromY = stateMachine._validEventNamesByState[Y_STATE]

			expect(validEventNamesFromX).to.be.a("table")
			expect(validEventNamesFromY).to.be.a("table")

			expect(Dict.count(validEventNamesFromX)).to.equal(1)
			expect(Dict.includes(validEventNamesFromX, TO_Y_EVENT)).to.be.ok()

			expect(Dict.count(validEventNamesFromY)).to.equal(2)
			expect(Dict.includes(validEventNamesFromY, TO_X_EVENT)).to.be.ok()
			expect(Dict.includes(validEventNamesFromY, TO_Y_EVENT)).to.be.ok()
		end)

		it("should set handlers by event name", function()
			local eventsByName = {
				[TO_Y_EVENT] = {
					canBeFinal = false,
					from = {
						[X_STATE] = {
							beforeAsync = TO_Y_HANDLER,
						},
						[Y_STATE] = {
							beforeAsync = TO_Y_HANDLER,
						},
					},
				},
				[TO_X_EVENT] = {
					canBeFinal = false,
					from = {
						[Y_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine = StateMachine.new(X_STATE, eventsByName)
			local handlers = stateMachine._handlersByEventName

			expect(Dict.count(handlers)).to.equal(2)
			expect(handlers[TO_X_EVENT]).to.be.a("function")
			expect(handlers[TO_Y_EVENT]).to.be.a("function")
		end)

		it("should make signals available", function()
			local eventsByName = {
				[TO_X_EVENT] = {
					canBeFinal = true,
					from = {
						[X_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine = StateMachine.new(X_STATE, eventsByName)

			expect(stateMachine[BEFORE_EVENT_SIGNAL]).to.be.ok()
			expect(stateMachine[LEAVING_STATE_SIGNAL]).to.be.ok()
			expect(stateMachine[STATE_ENTERED_SIGNAL]).to.be.ok()
			expect(stateMachine[AFTER_EVENT_SIGNAL]).to.be.ok()
			expect(stateMachine[FINISHED_SIGNAL]).to.be.ok()
		end)
	end)

	-- Done
	describe("handle", function()
		describe("should fire signals", function()
			it("in the correct order", function()
				local initialState = X_STATE
				local eventsByName = {
					[FINISH_EVENT] = {
						canBeFinal = true,
						from = {
							[X_STATE] = {
								beforeAsync = FINISH_HANDLER,
							},
						},
					},
				}

				local stateMachine = StateMachine.new(initialState, eventsByName)
				local resultSignalOrder = {}

				stateMachine:handle(FINISH_EVENT)

				local mainThread = coroutine.running()
				local timeout = 0.5
				local timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, true)
				end)

				-- Set up event connections
				for _, signalName in ORDERED_SIGNALS do
					stateMachine[signalName]:Connect(function(_, _)
						if coroutine.status(timeoutThread) ~= "suspended" then
							return
						end
						table.insert(resultSignalOrder, signalName)

						if #resultSignalOrder == #ORDERED_SIGNALS then
							task.cancel(timeoutThread)
							coroutine.resume(mainThread, false)
						end
					end)
				end

				local didTimeOut = coroutine.yield(mainThread)
				if didTimeOut then
					local numSignalsNotFired = #ORDERED_SIGNALS - #resultSignalOrder
					warn(
						`Timed out waiting for {numSignalsNotFired} signal{plural(numSignalsNotFired)} to fire after {timeout} seconds {debug.traceback()}`
					)
				end

				for index, expectedSignalName in ORDERED_SIGNALS do
					expect(resultSignalOrder[index]).to.equal(expectedSignalName)
				end
			end)

			describe(`with the correct parameters and state`, function()
				local initialState = X_STATE
				local variadicArgs = { "test", false, nil, 3.5 }
				local timeout = 0.5
				local handledEventName = TO_Y_EVENT
				local expectedAfterState = Y_STATE
				local receivedParameters
				local eventsByName = {
					[TO_Y_EVENT] = {
						canBeFinal = false,
						from = {
							[X_STATE] = {
								beforeAsync = TO_Y_HANDLER,
							},
						},
					},
					[TO_X_EVENT] = {
						canBeFinal = false,
						from = {
							[Y_STATE] = {
								beforeAsync = TO_X_HANDLER,
							},
						},
					},
					[FINISH_EVENT] = {
						canBeFinal = true,
						from = {
							[X_STATE] = {
								beforeAsync = FINISH_HANDLER,
							},
						},
					},
				}

				local stateMachine

				beforeEach(function()
					receivedParameters = nil
					stateMachine = StateMachine.new(initialState, eventsByName)
				end)

				it(BEFORE_EVENT_SIGNAL, function()
					local mainThread = coroutine.running()
					local timeoutThread = task.delay(timeout, function()
						coroutine.resume(mainThread, true)
					end)

					stateMachine[BEFORE_EVENT_SIGNAL]:Connect(function(...)
						receivedParameters = { ... }
						task.cancel(timeoutThread)
						coroutine.resume(mainThread, false)
					end)

					stateMachine:handle(handledEventName, table.unpack(variadicArgs))

					local didTimeOut = coroutine.yield(mainThread)
					expect(didTimeOut).to.equal(false)
					expect(#receivedParameters).to.equal(2)
					expect(receivedParameters[1]).to.equal(handledEventName)
					expect(receivedParameters[2]).to.equal(initialState)
					expect(stateMachine._currentState).to.equal(initialState)
				end)

				it(LEAVING_STATE_SIGNAL, function()
					local expectedAfterState = Y_STATE
					local mainThread = coroutine.running()
					local timeoutThread = task.delay(timeout, function()
						coroutine.resume(mainThread, true)
					end)

					stateMachine[LEAVING_STATE_SIGNAL]:Connect(function(...)
						receivedParameters = { ... }
						task.cancel(timeoutThread)
						coroutine.resume(mainThread, false)
					end)

					stateMachine:handle(handledEventName, table.unpack(variadicArgs))

					local didTimeOut = coroutine.yield(mainThread)
					expect(didTimeOut).to.equal(false)
					expect(#receivedParameters).to.equal(2)
					expect(receivedParameters[1]).to.equal(initialState)
					expect(receivedParameters[2]).to.equal(expectedAfterState)
					expect(stateMachine._currentState).to.equal(initialState)
				end)

				it(STATE_ENTERED_SIGNAL, function()
					local expectedAfterState = Y_STATE
					local mainThread = coroutine.running()
					local timeoutThread = task.delay(timeout, function()
						coroutine.resume(mainThread, true)
					end)

					stateMachine[STATE_ENTERED_SIGNAL]:Connect(function(...)
						receivedParameters = { ... }
						task.cancel(timeoutThread)
						coroutine.resume(mainThread, false)
					end)

					stateMachine:handle(handledEventName, table.unpack(variadicArgs))

					local didTimeOut = coroutine.yield(mainThread)
					expect(didTimeOut).to.equal(false)
					expect(#receivedParameters).to.equal(2)
					expect(receivedParameters[1]).to.equal(expectedAfterState)
					expect(receivedParameters[2]).to.equal(initialState)
					expect(stateMachine._currentState).to.equal(expectedAfterState)
				end)

				it(AFTER_EVENT_SIGNAL, function()
					local expectedAfterState = Y_STATE
					local mainThread = coroutine.running()
					local timeoutThread = task.delay(timeout, function()
						coroutine.resume(mainThread, true)
					end)

					stateMachine[AFTER_EVENT_SIGNAL]:Connect(function(...)
						receivedParameters = { ... }
						task.cancel(timeoutThread)
						coroutine.resume(mainThread, false)
					end)

					stateMachine:handle(handledEventName, table.unpack(variadicArgs))

					local didTimeOut = coroutine.yield(mainThread)
					expect(didTimeOut).to.equal(false)
					expect(#receivedParameters).to.equal(3)
					expect(receivedParameters[1]).to.equal(handledEventName)
					expect(receivedParameters[2]).to.equal(expectedAfterState)
					expect(receivedParameters[3]).to.equal(initialState)
					expect(stateMachine._currentState).to.equal(expectedAfterState)
				end)

				it(FINISHED_SIGNAL, function()
					local mainThread = coroutine.running()
					local timeoutThread = task.delay(timeout, function()
						coroutine.resume(mainThread, true)
					end)

					stateMachine[FINISHED_SIGNAL]:Connect(function(...)
						receivedParameters = { ... }
						task.cancel(timeoutThread)
						coroutine.resume(mainThread, false)
					end)

					stateMachine:handle(FINISH_EVENT, table.unpack(variadicArgs))

					local didTimeOut = coroutine.yield(mainThread)
					expect(didTimeOut).to.equal(false)
					expect(#receivedParameters).to.equal(1)
					expect(receivedParameters[1]).to.equal(initialState)
					expect(stateMachine._currentState).to.equal(FINISH_STATE)
				end)
			end)
		end)

		describe("should invoke callbacks", function()
			it("at the correct time", function()
				local initialState = X_STATE
				local mainThread = coroutine.running()
				local timeoutThreadBefore, timeoutThreadAfter
				local firedSignals = {}
				local eventsByName = {
					[FINISH_EVENT] = {
						canBeFinal = true,
						from = {
							[X_STATE] = {
								beforeAsync = function()
									task.cancel(timeoutThreadBefore)
									coroutine.resume(mainThread, "beforeAsync")
									return FINISH_STATE
								end,
								afterAsync = function()
									task.cancel(timeoutThreadAfter)
									coroutine.resume(mainThread, "afterAsync")
								end,
							},
						},
					},
				}

				local stateMachine = StateMachine.new(initialState, eventsByName)

				stateMachine:handle(FINISH_EVENT)

				stateMachine[BEFORE_EVENT_SIGNAL]:Connect(function()
					table.insert(firedSignals, BEFORE_EVENT_SIGNAL)
				end)

				stateMachine[LEAVING_STATE_SIGNAL]:Connect(function()
					table.insert(firedSignals, LEAVING_STATE_SIGNAL)
				end)

				stateMachine[STATE_ENTERED_SIGNAL]:Connect(function()
					table.insert(firedSignals, STATE_ENTERED_SIGNAL)
				end)

				stateMachine[AFTER_EVENT_SIGNAL]:Connect(function()
					table.insert(firedSignals, AFTER_EVENT_SIGNAL)
				end)

				stateMachine[FINISHED_SIGNAL]:Connect(function()
					table.insert(firedSignals, FINISHED_SIGNAL)
				end)

				local timeout = 0.5
				timeoutThreadBefore = task.delay(timeout, function()
					coroutine.resume(mainThread, `timeout waiting {timeout} seconds for beforeAsync invocation`)
				end)
				local invokedCallback = coroutine.yield()
				expect(invokedCallback).to.equal("beforeAsync")
				local expectedFiredSignals = { BEFORE_EVENT_SIGNAL }
				expect(firedSignals[1]).to.equal(expectedFiredSignals[1])
				expect(#firedSignals).to.equal(#expectedFiredSignals)

				timeoutThreadAfter = task.delay(timeout, function()
					coroutine.resume(mainThread, `timeout waiting {timeout} seconds for afterAsync invocation`)
				end)
				invokedCallback = coroutine.yield()
				expect(invokedCallback).to.equal("afterAsync")
				expectedFiredSignals = {
					BEFORE_EVENT_SIGNAL,
					LEAVING_STATE_SIGNAL,
					STATE_ENTERED_SIGNAL,
				}
				for index, expectedFiredSignal in expectedFiredSignals do
					expect(firedSignals[index]).to.equal(expectedFiredSignal)
				end
				expect(#firedSignals).to.equal(#expectedFiredSignals)
			end)

			it("with the correct parameters and state", function()
				local initialState = X_STATE
				local variadicArgs = { "test", false, nil, 3.5 }
				local timeout = 0.5
				local timeoutThread
				local mainThread = coroutine.running()
				local handledEventName = FINISH_EVENT
				local expectedAfterState = FINISH_STATE
				local receivedParameters
				local stateMachine
				local eventsByName = {
					[FINISH_EVENT] = {
						canBeFinal = true,
						from = {
							[X_STATE] = {
								beforeAsync = function(...)
									receivedParameters = { ... }
									task.cancel(timeoutThread)
									coroutine.resume(mainThread, "beforeAsync")
									return FINISH_STATE
								end,
								afterAsync = function(...)
									receivedParameters = { ... }
									task.cancel(timeoutThread)
									coroutine.resume(mainThread, "afterAsync")
								end,
							},
						},
					},
				}

				stateMachine = StateMachine.new(initialState, eventsByName)

				-- Test beforeAsync
				timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, `timeout waiting {timeout} seconds for beforeAsync invocation`)
				end)

				stateMachine:handle(handledEventName, table.unpack(variadicArgs))

				local invokedCallback = coroutine.yield(mainThread)
				expect(invokedCallback).to.equal("beforeAsync")
				for index, variadicArg in variadicArgs do
					expect(receivedParameters[index]).to.equal(variadicArg)
				end
				expect(#receivedParameters).to.equal(#variadicArgs)
				expect(stateMachine._currentState).to.equal(initialState)

				-- Test afterAsync
				timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, `timeout waiting {timeout} seconds for afterAsync invocation`)
				end)

				local invokedCallback = coroutine.yield(mainThread)
				expect(invokedCallback).to.equal("afterAsync")
				for index, variadicArg in variadicArgs do
					expect(receivedParameters[index]).to.equal(variadicArg)
				end
				expect(#receivedParameters).to.equal(#variadicArgs)
				expect(stateMachine._currentState).to.equal(expectedAfterState)
			end)
		end)
	end)

	-- Placeholder
	-- describe("getState", function()
	-- 	it("should return the current state correctly", function()
	-- 		local initialState = "A"
	-- 		local eventsByName = {
	-- 			toB = {
	-- 				canBeFinal = false,
	-- 				from = {
	-- 					A = {
	-- 						beforeAsync = TO_Y_HANDLER,
	-- 					},
	-- 				},
	-- 			},
	-- 		}

	-- 		local stateMachine = StateMachine.new(initialState, eventsByName)

	-- 		-- Test getting the current state
	-- 		local state = stateMachine:getState()
	-- 		expect(state).to.equal(initialState)

	-- 		-- Test getting the state after a transition
	-- 		stateMachine:handle("toB")
	-- 		state = stateMachine:getState()
	-- 		expect(state).to.equal("B")
	-- 	end)
	-- end)

	-- Placeholder
	-- describe("getValidEvents", function()
	-- 	it("should return valid events correctly", function()
	-- 		local initialState = "A"
	-- 		local eventsByName = {
	-- 			toB = {
	-- 				canBeFinal = false,
	-- 				from = {
	-- 					A = {
	-- 						beforeAsync = TO_Y_HANDLER,
	-- 					},
	-- 				},
	-- 			},
	-- 			toA = {
	-- 				canBeFinal = false,
	-- 				from = {
	-- 					B = {
	-- 						beforeAsync = TO_X_HANDLER,
	-- 					},
	-- 				},
	-- 			},
	-- 		}

	-- 		local stateMachine = StateMachine.new(initialState, eventsByName)

	-- 		-- Test getting valid events for the initial state
	-- 		local validEvents = stateMachine:getValidEvents()
	-- 		expect(#validEvents).to.equal(1)
	-- 		expect(validEvents[1]).to.equal("toB")

	-- 		-- Test getting valid events after a transition
	-- 		stateMachine:handle("toB")
	-- 		validEvents = stateMachine:getValidEvents()
	-- 		expect(#validEvents).to.equal(1)
	-- 		expect(validEvents[1]).to.equal("toA")
	-- 	end)
	-- end)

	-- Done
	describe("_isDebugEnabled", function()
		it("should default to false", function()
			local eventsByName = {
				[TO_X_EVENT] = {
					canBeFinal = true,
					from = {
						[X_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine = StateMachine.new(X_STATE, eventsByName)
			expect(stateMachine._isDebugEnabled).to.equal(false)
		end)

		it("setter should set the value correctly", function()
			local eventsByName = {
				[TO_X_EVENT] = {
					canBeFinal = true,
					from = {
						[X_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local stateMachine = StateMachine.new(X_STATE, eventsByName)

			stateMachine:setDebugEnabled(true)
			expect(stateMachine._isDebugEnabled).to.equal(true)

			stateMachine:setDebugEnabled(false)
			expect(stateMachine._isDebugEnabled).to.equal(false)
		end)
	end)

	-- Placeholder
	-- describe("destroy", function()
	-- 	it("should destroy correctly", function()
	-- 		local initialState = "A"
	-- 		local eventsByName = {
	-- 			toB = {
	-- 				canBeFinal = false,
	-- 				from = {
	-- 					A = {
	-- 						beforeAsync = TO_Y_HANDLER,
	-- 					},
	-- 				},
	-- 			},
	-- 		}

	-- 		local stateMachine = StateMachine.new(initialState, eventsByName)

	-- 		-- Test destroying the state machine
	-- 		stateMachine:destroy()
	-- 		expect(stateMachine._isDestroyed).to.equal(true)
	-- 		expect(stateMachine[BEFORE_EVENT_SIGNAL]:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine[LEAVING_STATE_SIGNAL]:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine[STATE_ENTERED_SIGNAL]:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine[AFTER_EVENT_SIGNAL]:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine[FINISHED_SIGNAL]:getConnectionCount()).to.equal(0)
	-- 	end)
	-- end)
end

-- return function()
-- 	local StateMachine = require(script.Parent.Parent.StateMachine)

-- 	local function createTestMachine()
-- 		local states = {
-- 			["A"] = {
-- 				["toB"] = {
-- 					canBeFinal = false,
-- 					from = {
-- 						["A"] = {
-- 							beforeAsync = function()
-- 								wait(0.1)
-- 								return "B"
-- 							end,
-- 						},
-- 					},
-- 				},
-- 			},
-- 			["B"] = {
-- 				["toC"] = {
-- 					canBeFinal = false,
-- 					from = {
-- 						["B"] = {
-- 							beforeAsync = function()
-- 								wait(0.1)
-- 								return "C"
-- 							end,
-- 						},
-- 					},
-- 				},
-- 				["toA"] = {
-- 					canBeFinal = false,
-- 					from = {
-- 						["B"] = {
-- 							beforeAsync = function()
-- 								wait(0.1)
-- 								return "A"
-- 							end,
-- 						},
-- 					},
-- 				},
-- 			},
-- 			["C"] = {
-- 				["toA"] = {
-- 					canBeFinal = true,
-- 					from = {
-- 						["C"] = {
-- 							beforeAsync = function()
-- 								wait(0.1)
-- 								return nil
-- 							end,
-- 						},
-- 					},
-- 				},
-- 			},
-- 		}

-- 		local machine = StateMachine.new("A", states)
-- 		machine:setDebugEnabled(true)
-- 		return machine
-- 	end

-- 	describe("new", function()
-- 		it("should create a new StateMachine", function()
-- 			local machine = createTestMachine()
-- 			expect(machine).to.be.ok()
-- 		end)

-- 		it("should require an initial state", function()
-- 			expect(function()
-- 				StateMachine.new()
-- 			end).to.throw()
-- 		end)

-- 		it("should require events", function()
-- 			expect(function()
-- 				StateMachine.new("A")
-- 			end).to.throw()
-- 		end)
-- 	end)

-- 	describe("handle", function()
-- 		it("should process events", function()
-- 			local machine = createTestMachine()

-- 			local events = {}
-- 			machine[FINISHED_SIGNAL]:Connect(function(state)
-- 				table.insert(events, state)
-- 			end)

-- 			machine:handle("toB")
-- 			machine:handle("toC")
-- 			machine:handle("toA")

-- 			wait(0.4)

-- 			expect(events).to.be.ok()
-- 			expect(events[1]).to.equal("B")
-- end
