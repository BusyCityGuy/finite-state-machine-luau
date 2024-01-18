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

local A = "A"
local B = "B"
local C = "C"

local function to(state: string)
	return function()
		return state
	end
end

return function()
	local StateMachine = require(ReplicatedStorage.Source.StateMachine)

	describe("new", function()
		it("should return a new state machine", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine1 = StateMachine.new(initialState, eventsByName)
			local stateMachine2 = StateMachine.new(initialState, eventsByName)

			expect(stateMachine1).to.be.ok()
			expect(stateMachine2).to.be.ok()
			expect(stateMachine1).never.to.equal(stateMachine2)
		end)

		it("should set initial state", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)
			expect(stateMachine._currentState).to.equal(initialState)
		end)

		it("should set valid event names by state", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
						B = {
							beforeAsync = to(B),
						},
					},
				},
				toA = {
					canBeFinal = false,
					from = {
						B = {
							beforeAsync = to(A),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)
			expect(stateMachine._validEventNamesByState.A).to.be.ok()
			expect(stateMachine._validEventNamesByState.A[1]).to.equal("toB")
			expect(stateMachine._validEventNamesByState.B).to.be.ok()
			expect(stateMachine._validEventNamesByState.B[1]).to.equal("toB")
			expect(stateMachine._validEventNamesByState.B[2]).to.equal("toA")
		end)

		it("should set handlers by event name", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)
			expect(stateMachine._handlersByEventName.toB).to.be.ok()
			expect(stateMachine._validEventNamesByState.A[1]).to.equal("toB")
		end)
	end)

	describe("handle", function()
		it("should handle events correctly", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)

			-- Test handling a valid event
			stateMachine:handle("toB")
			expect(stateMachine._currentState).to.equal("B")

			-- Test handling an invalid event
			local success, errorMessage = pcall(function()
				stateMachine:handle("toA")
			end)
			expect(success).never.to.be.ok()
			expect(errorMessage).to.be.a("string")
			expect(errorMessage:find("Invalid event name passed to handle")).to.be.ok()
		end)
	end)

	describe("getState", function()
		it("should return the current state correctly", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)

			-- Test getting the current state
			local state = stateMachine:getState()
			expect(state).to.equal(initialState)

			-- Test getting the state after a transition
			stateMachine:handle("toB")
			state = stateMachine:getState()
			expect(state).to.equal("B")
		end)
	end)

	describe("getValidEvents", function()
		it("should return valid events correctly", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
				toA = {
					canBeFinal = false,
					from = {
						B = {
							beforeAsync = to(A),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)

			-- Test getting valid events for the initial state
			local validEvents = stateMachine:getValidEvents()
			expect(#validEvents).to.equal(1)
			expect(validEvents[1]).to.equal("toB")

			-- Test getting valid events after a transition
			stateMachine:handle("toB")
			validEvents = stateMachine:getValidEvents()
			expect(#validEvents).to.equal(1)
			expect(validEvents[1]).to.equal("toA")
		end)
	end)

	describe("setDebugEnabled", function()
		it("should set debug enabled correctly", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)

			-- Test setting debug enabled
			stateMachine:setDebugEnabled(true)
			expect(stateMachine._isDebugEnabled).to.equal(true)

			-- Test setting debug disabled
			stateMachine:setDebugEnabled(false)
			expect(stateMachine._isDebugEnabled).to.equal(false)
		end)
	end)

	describe("destroy", function()
		it("should destroy correctly", function()
			local initialState = "A"
			local eventsByName = {
				toB = {
					canBeFinal = false,
					from = {
						A = {
							beforeAsync = to(B),
						},
					},
				},
			}

			local stateMachine = StateMachine.new(initialState, eventsByName)

			-- Test destroying the state machine
			stateMachine:destroy()
			expect(stateMachine._isDestroyed).to.equal(true)
			expect(stateMachine.beforeEvent:getConnectionCount()).to.equal(0)
			expect(stateMachine.leavingState:getConnectionCount()).to.equal(0)
			expect(stateMachine.stateEntered:getConnectionCount()).to.equal(0)
			expect(stateMachine.afterEvent:getConnectionCount()).to.equal(0)
			expect(stateMachine.finished:getConnectionCount()).to.equal(0)
		end)
	end)
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
