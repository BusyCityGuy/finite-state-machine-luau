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

-- 		self.beforeEvent:Fire(eventName, beforeState)
-- 		local afterState = transition.beforeAsync(table.unpack(args))
-- 		if self._isDestroyed then
-- 			return
-- 		end

-- 		self:_log(`Transitioning from {beforeState} to {afterState}`)

-- 		if afterState ~= beforeState then
-- 			self.leavingState:Fire(beforeState, afterState)
-- 			self._currentState = afterState
-- 			self.stateEntered:Fire(afterState, beforeState)
-- 			self:_log("Valid events:", self:getValidEvents())
-- 		end

-- 		if transition.afterAsync then
-- 			transition.afterAsync(table.unpack(args))
-- 			if self._isDestroyed then
-- 				return
-- 			end
-- 		end

-- 		self.afterEvent:Fire(eventName, afterState, beforeState)

-- 		local isFinished = not afterState

-- 		if isFinished then
-- 			assert(
-- 				event.canBeFinal,
-- 				`Transition did not return next state during a non-final event {eventName} with state {beforeState}`
-- 			)
-- 			-- State machine finished
-- 			self:_log("Finished")
-- 			self.finished:Fire(beforeState)
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
-- 	self.beforeEvent:DisconnectAll()
-- 	self.leavingState:DisconnectAll()
-- 	self.stateEntered:DisconnectAll()
-- 	self.afterEvent:DisconnectAll()
-- 	self.finished:DisconnectAll()
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

-- Events
local TO_X_EVENT = "TO_X_EVENT"
local TO_Y_EVENT = "TO_Y_EVENT"

-- Transition handlers
local function to(state: string)
	return function()
		return state
	end
end
local TO_X_HANDLER = to(X_STATE)
local TO_Y_HANDLER = to(Y_STATE)

return function()
	local StateMachine = require(ReplicatedStorage.Source.StateMachine)
	local Freeze = require(TestService.Source.freeze)

	-- Shortening things is generally bad practice, but this greatly improves readability of tests
	local Dict = Freeze.Dictionary

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
	end)

	-- describe("handle", function()
	-- 	it("should handle events correctly", function()
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

	-- 		-- Test handling a valid event
	-- 		stateMachine:handle("toB")
	-- 		expect(stateMachine._currentState).to.equal("B")

	-- 		-- Test handling an invalid event
	-- 		local success, errorMessage = pcall(function()
	-- 			stateMachine:handle("toA")
	-- 		end)
	-- 		expect(success).never.to.be.ok()
	-- 		expect(errorMessage).to.be.a("string")
	-- 		expect(errorMessage:find("Invalid event name passed to handle")).to.be.ok()
	-- 	end)
	-- end)

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

	describe("debugEnabled", function()
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
	-- 		expect(stateMachine.beforeEvent:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine.leavingState:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine.stateEntered:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine.afterEvent:getConnectionCount()).to.equal(0)
	-- 		expect(stateMachine.finished:getConnectionCount()).to.equal(0)
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
-- 			machine.finished:Connect(function(state)
-- 				table.insert(events, state)
-- 			end)

-- 			machine:handle("toB")
-- 			machine:handle("toC")
-- 			machine:handle("toA")

-- 			wait(0.4)

-- 			expect(events).to.be.ok()
-- 			expect(events[1]).to.equal("B")
-- end
