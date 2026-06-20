--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local JestGlobals = require(TestService.Source.DevPackages.JestGlobals)
local StateQ = require(ReplicatedStorage.Source.Packages.StateQ)

-- Shortening these for readability
local it = JestGlobals.it
local expect = JestGlobals.expect
local describe = JestGlobals.describe
local beforeEach = JestGlobals.beforeEach
local jest = JestGlobals.jest

-- States
local X_STATE = "X_STATE"
local Y_STATE = "Y_STATE"
local FINISH_STATE = nil

-- Events
local TO_X_EVENT = "TO_X_EVENT"
local TO_Y_EVENT = "TO_Y_EVENT"
local STAY_X_EVENT = "STAY_X_EVENT"
local FINISH_EVENT = "FINISH_EVENT"
local THROW_EVENT = "THROW_EVENT"
local AFTER_THROW_EVENT = "AFTER_THROW_EVENT"
local BAD_RETURN_EVENT = "BAD_RETURN_EVENT"
local NONFINAL_NIL_EVENT = "NONFINAL_NIL_EVENT"

-- Signals
local BEFORE_EVENT_SIGNAL = "beforeEvent"
local LEAVING_STATE_SIGNAL = "leavingState"
local STATE_ENTERED_SIGNAL = "stateEntered"
local AFTER_EVENT_SIGNAL = "afterEvent"
local FINISHED_SIGNAL = "finished"
local EVENT_ERRORED_SIGNAL = "eventErrored"

-- The five signals that fire in order during a normal event
local ORDERED_SIGNALS = {
	BEFORE_EVENT_SIGNAL,
	LEAVING_STATE_SIGNAL,
	STATE_ENTERED_SIGNAL,
	AFTER_EVENT_SIGNAL,
	FINISHED_SIGNAL,
}

local ALL_SIGNALS = {
	BEFORE_EVENT_SIGNAL,
	LEAVING_STATE_SIGNAL,
	STATE_ENTERED_SIGNAL,
	AFTER_EVENT_SIGNAL,
	FINISHED_SIGNAL,
	EVENT_ERRORED_SIGNAL,
}

local PHASE = StateQ.EventErrorPhase

local TEST_TIMEOUT_MS = 500

-- A beforeAsync that synchronously transitions to the given state
local function to(state: string?)
	return function()
		return state
	end
end

-- A beforeAsync that yields a frame before transitioning, exercising the async path
local function toAfterYield(state: string?)
	return function()
		task.wait()
		return state
	end
end

-- A callback that always throws the given message, for beforeAsync/afterAsync failure tests
local function throwingHandler(message: string)
	return function()
		error(message)
	end
end

-- Builds a Transition table
local function transition(beforeAsync, afterAsync)
	return {
		beforeAsync = beforeAsync,
		afterAsync = afterAsync,
	}
end

-- Builds an Event table
local function event(canBeFinal: boolean, from)
	return {
		canBeFinal = canBeFinal,
		from = from,
	}
end

-- The common machine definition reused by most tests:
--   X --TO_Y--> Y,  Y --TO_X--> X,  X --STAY_X_EVENT--> X,  X --FINISH--> (finished)
local function standardEvents()
	return {
		[TO_Y_EVENT] = event(false, { [X_STATE] = transition(to(Y_STATE)) }),
		[TO_X_EVENT] = event(false, { [Y_STATE] = transition(to(X_STATE)) }),
		[STAY_X_EVENT] = event(false, { [X_STATE] = transition(to(X_STATE)) }),
		[FINISH_EVENT] = event(true, { [X_STATE] = transition(to(FINISH_STATE)) }),
	}
end

-- Constructs a machine, defaulting to X_STATE + standardEvents()
local function makeMachine(options)
	options = options or {}
	return StateQ.new(
		if options.initialState ~= nil then options.initialState else X_STATE,
		options.events or standardEvents(),
		options.name,
		options.isDebugEnabled,
		options.maxQueueLength
	)
end

-- Generates a linear N-state chain at runtime: State1 --Event1--> State2 --Event2--> ... --EventN--> (finished)
local function generateChainMachine(stateCount: number)
	local events = {}
	for i = 1, stateCount - 1 do
		events[`Event{i}`] = event(false, { [`State{i}`] = transition(to(`State{i + 1}`)) })
	end
	events[`Event{stateCount}`] = event(true, { [`State{stateCount}`] = transition(to(FINISH_STATE)) })

	return {
		initialState = "State1",
		events = events,
		eventCount = stateCount,
	}
end

-- Connects to a signal, disconnects after the first fire, and forwards the args
-- FIXME: Should probably add :Once() as a method on Signal. Maybe some other open source signals out there already have it
local function onceSignal(signal, callback)
	local connection
	connection = signal:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

-- Runs async assertions, then resolves the test via done (passing any failure through)
local function settle(done, assertions)
	local success, result = xpcall(assertions, debug.traceback)
	if success then
		done()
	else
		done(result)
	end
end

describe("StateQ.new", function()
	describe("errors if given a bad type for", function()
		local validEvents = {
			[TO_X_EVENT] = event(true, { [X_STATE] = transition(to(X_STATE)) }),
		}

		describe("the initial state (#1)", function()
			it("nil", function()
				expect(function()
					StateQ.new(nil :: any, validEvents)
				end).toThrow("Bad tuple index #1")
			end)

			for _, badValue in { 1, true, {} } do
				it(`a {typeof(badValue)}`, function()
					expect(function()
						StateQ.new(badValue, validEvents)
					end).toThrow("Bad tuple index #1")
				end)
			end

			it("but accepts a string", function()
				expect(function()
					StateQ.new(X_STATE, validEvents)
				end).never.toThrow()
			end)
		end)

		describe("the events map (#2)", function()
			it("nil", function()
				expect(function()
					StateQ.new(X_STATE, nil :: any)
				end).toThrow("Bad tuple index #2")
			end)

			for _, badValue in { 1, true, { "bad", "type" } } do
				it(`a {typeof(badValue)}`, function()
					expect(function()
						StateQ.new(X_STATE, badValue)
					end).toThrow("Bad tuple index #2")
				end)
			end

			it("but accepts a valid events map", function()
				expect(function()
					StateQ.new(X_STATE, validEvents)
				end).never.toThrow()
			end)
		end)

		describe("the name (#3)", function()
			for _, badValue in { 1, true, {} } do
				it(`a {typeof(badValue)}`, function()
					expect(function()
						StateQ.new(X_STATE, validEvents, badValue)
					end).toThrow("Bad tuple index #3")
				end)
			end

			for _, goodValue in { "a name", "" } do
				it(`but accepts the string "{goodValue}"`, function()
					expect(function()
						StateQ.new(X_STATE, validEvents, goodValue)
					end).never.toThrow()
				end)
			end

			it("but accepts nil", function()
				expect(function()
					StateQ.new(X_STATE, validEvents, nil)
				end).never.toThrow()
			end)
		end)

		describe("the debug flag (#4)", function()
			for _, badValue in { 1, "bad", {} } do
				it(`a {typeof(badValue)}`, function()
					expect(function()
						StateQ.new(X_STATE, validEvents, nil, badValue)
					end).toThrow("Bad tuple index #4")
				end)
			end

			for _, goodValue in { true, false } do
				it(`but accepts {tostring(goodValue)}`, function()
					expect(function()
						StateQ.new(X_STATE, validEvents, nil, goodValue)
					end).never.toThrow()
				end)
			end

			it("but accepts nil", function()
				expect(function()
					StateQ.new(X_STATE, validEvents, nil, nil)
				end).never.toThrow()
			end)
		end)

		describe("the max queue length (#5)", function()
			for _, badValue in { "bad", true, {}, 0, -1 } do
				it(`a non-positive or non-number value: {tostring(badValue)}`, function()
					expect(function()
						StateQ.new(X_STATE, validEvents, nil, nil, badValue)
					end).toThrow("Bad tuple index #5")
				end)
			end

			for _, goodValue in { 1, 100 } do
				it(`but accepts the positive number {goodValue}`, function()
					expect(function()
						StateQ.new(X_STATE, validEvents, nil, nil, goodValue)
					end).never.toThrow()
				end)
			end

			it("but accepts nil", function()
				expect(function()
					StateQ.new(X_STATE, validEvents, nil, nil, nil)
				end).never.toThrow()
			end)
		end)
	end)

	it("returns a new, unique state machine", function()
		local stateQ1 = makeMachine()
		local stateQ2 = makeMachine()

		expect(stateQ1).toBeInstanceOf(StateQ)
		expect(stateQ2).toBeInstanceOf(StateQ)
		expect(stateQ1 == stateQ2).toBe(false)
	end)

	describe("names the machine", function()
		it("with a generated default when none is given", function()
			expect(makeMachine():getName()).toEqual(expect.stringMatching("^Machine%d+$"))
		end)

		it("with the provided name", function()
			expect(makeMachine({ name = "MyMachine" }):getName()).toBe("MyMachine")
		end)
	end)

	describe("initializes", function()
		-- An event reachable from two states, to exercise the grouping logic
		local eventsByName = {
			[TO_Y_EVENT] = event(false, {
				[X_STATE] = transition(to(Y_STATE)),
				[Y_STATE] = transition(to(Y_STATE)),
			}),
			[TO_X_EVENT] = event(false, {
				[Y_STATE] = transition(to(X_STATE)),
			}),
		}

		it("the current state to the initial state", function()
			expect(makeMachine({ initialState = X_STATE }):getState()).toBe(X_STATE)
		end)

		it("the valid event names grouped by state", function()
			local stateQ = StateQ.new(X_STATE, eventsByName)
			local validFromX = stateQ._validEventNamesByState[X_STATE]
			local validFromY = stateQ._validEventNamesByState[Y_STATE]

			expect(#validFromX).toBe(1)
			expect(table.find(validFromX, TO_Y_EVENT)).never.toBeNil()

			expect(#validFromY).toBe(2)
			expect(table.find(validFromY, TO_X_EVENT)).never.toBeNil()
			expect(table.find(validFromY, TO_Y_EVENT)).never.toBeNil()
		end)

		it("a handler for each event name", function()
			local stateQ = StateQ.new(X_STATE, eventsByName)
			local handlers = stateQ._handlersByEventName

			expect(handlers[TO_X_EVENT]).toEqual(expect.any("function"))
			expect(handlers[TO_Y_EVENT]).toEqual(expect.any("function"))
		end)

		it(`all {#ALL_SIGNALS} signals`, function()
			local stateQ = makeMachine()
			for _, signalName in ALL_SIGNALS do
				expect(stateQ[signalName]).never.toBeNil()
			end
		end)
	end)
end)

describe("handle", function()
	it("throws synchronously for a non-string event name", function()
		local stateQ = makeMachine()
		for _, badValue in { 1, true, {} } do
			expect(function()
				stateQ:handle(badValue)
			end).toThrow(`string expected, got {typeof(badValue)}`)
		end
	end)

	it("throws synchronously for an unknown event name", function()
		local stateQ = makeMachine()
		expect(function()
			stateQ:handle("nonexistent")
		end).toThrow("Invalid event name passed to handle: nonexistent")
	end)

	it("throws synchronously when the machine was destroyed", function()
		local stateQ = makeMachine()
		stateQ:destroy()
		expect(function()
			stateQ:handle(TO_Y_EVENT)
		end).toThrow("after the state machine was destroyed")
	end)

	it("returns before the async transition completes", function()
		local events = {
			[TO_Y_EVENT] = event(false, { [X_STATE] = transition(toAfterYield(Y_STATE)) }),
		}
		local stateQ = makeMachine({ events = events })

		stateQ:handle(TO_Y_EVENT)

		-- The yielding transition has not run yet, so we are still in the initial state
		expect(stateQ:getState()).toBe(X_STATE)
	end)

	it("forwards the variadic args to the transition callbacks", function(_, done)
		local beforeArgs, afterArgs
		-- jest.fn() returns the mock and a plain forwarding function; t.callback requires a real
		-- function, so the transition uses the forwarding functions and we assert on the mocks.
		local beforeMock, beforeFn = jest.fn(function(...)
			beforeArgs = table.pack(...)
			return Y_STATE
		end)
		local afterMock, afterFn = jest.fn(function(...)
			afterArgs = table.pack(...)
		end)
		local events = {
			[TO_Y_EVENT] = event(false, { [X_STATE] = transition(beforeFn, afterFn) }),
		}
		local stateQ = makeMachine({ events = events })

		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(beforeArgs.n).toBe(4)
				expect(afterArgs.n).toBe(4)
				expect(beforeMock).toHaveBeenCalledWith("a", false, nil, 3.5)
				expect(afterMock).toHaveBeenCalledWith("a", false, nil, 3.5)
			end)
		end)

		stateQ:handle(TO_Y_EVENT, "a", false, nil, 3.5)
	end, TEST_TIMEOUT_MS)

	it("admits exactly maxQueueLength events and reports a queue-capacity error on the next", function(_, done)
		local stateQ = makeMachine({ maxQueueLength = 2 })
		local handled = false

		stateQ.eventErrored:Connect(function(errorInfo)
			if handled then
				return
			end
			handled = true
			settle(done, function()
				expect(errorInfo.phase).toBe(PHASE.queue)
				expect(errorInfo.message).toEqual(expect.stringContaining("Queue is at capacity"))
				expect(stateQ:getMaxQueueLength()).toBe(2)
			end)
		end)

		-- STAY_X_EVENT keeps the machine in X_STATE so every queued event stays valid.
		-- With maxQueueLength = 2, the first two are admitted and the third overflows.
		for _ = 1, 5 do
			stateQ:handle(STAY_X_EVENT)
		end
	end, TEST_TIMEOUT_MS)
end)

describe("signals", function()
	it("fire in the documented order", function(_, done)
		local stateQ = makeMachine()
		local firedOrder = {}
		local connections = {}

		for _, signalName in ORDERED_SIGNALS do
			table.insert(
				connections,
				stateQ[signalName]:Connect(function()
					table.insert(firedOrder, signalName)
					if #firedOrder == #ORDERED_SIGNALS then
						for _, connection in connections do
							connection:Disconnect()
						end
						settle(done, function()
							expect(firedOrder).toEqual(ORDERED_SIGNALS)
						end)
					end
				end)
			)
		end

		stateQ:handle(FINISH_EVENT)
	end, TEST_TIMEOUT_MS)

	describe("fire with the correct arguments and state", function()
		local stateQ
		beforeEach(function()
			stateQ = makeMachine()
		end)

		it("beforeEvent provides (eventName, beforeState) before the state changes", function(_, done)
			onceSignal(stateQ.beforeEvent, function(eventName, beforeState)
				settle(done, function()
					expect(eventName).toBe(TO_Y_EVENT)
					expect(beforeState).toBe(X_STATE)
					expect(stateQ:getState()).toBe(X_STATE)
				end)
			end)
			stateQ:handle(TO_Y_EVENT)
		end, TEST_TIMEOUT_MS)

		it("leavingState provides (beforeState, afterState) before the state changes", function(_, done)
			onceSignal(stateQ.leavingState, function(beforeState, afterState)
				settle(done, function()
					expect(beforeState).toBe(X_STATE)
					expect(afterState).toBe(Y_STATE)
					expect(stateQ:getState()).toBe(X_STATE)
				end)
			end)
			stateQ:handle(TO_Y_EVENT)
		end, TEST_TIMEOUT_MS)

		it("stateEntered provides (afterState, beforeState) after the state changes", function(_, done)
			onceSignal(stateQ.stateEntered, function(afterState, beforeState)
				settle(done, function()
					expect(afterState).toBe(Y_STATE)
					expect(beforeState).toBe(X_STATE)
					expect(stateQ:getState()).toBe(Y_STATE)
				end)
			end)
			stateQ:handle(TO_Y_EVENT)
		end, TEST_TIMEOUT_MS)

		it("afterEvent provides (eventName, afterState, beforeState) after the state changes", function(_, done)
			onceSignal(stateQ.afterEvent, function(eventName, afterState, beforeState)
				settle(done, function()
					expect(eventName).toBe(TO_Y_EVENT)
					expect(afterState).toBe(Y_STATE)
					expect(beforeState).toBe(X_STATE)
					expect(stateQ:getState()).toBe(Y_STATE)
				end)
			end)
			stateQ:handle(TO_Y_EVENT)
		end, TEST_TIMEOUT_MS)

		it("finished provides (beforeState) once the machine has no current state", function(_, done)
			onceSignal(stateQ.finished, function(beforeState)
				settle(done, function()
					expect(beforeState).toBe(X_STATE)
					expect(stateQ:getState()).toBe(FINISH_STATE)
				end)
			end)
			stateQ:handle(FINISH_EVENT)
		end, TEST_TIMEOUT_MS)
	end)

	it("skip leavingState and stateEntered on a self-transition", function(_, done)
		local stateQ = makeMachine()
		local beforeMock = jest.fn()
		local leavingMock = jest.fn()
		local enteredMock = jest.fn()

		stateQ.beforeEvent:Connect(beforeMock)
		stateQ.leavingState:Connect(leavingMock)
		stateQ.stateEntered:Connect(enteredMock)

		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(beforeMock).toHaveBeenCalled()
				expect(leavingMock).never.toHaveBeenCalled()
				expect(enteredMock).never.toHaveBeenCalled()
				expect(stateQ:getState()).toBe(X_STATE)
			end)
		end)

		stateQ:handle(STAY_X_EVENT)
	end, TEST_TIMEOUT_MS)

	it("does not fire finished when a canBeFinal event returns a real state", function(_, done)
		local events = {
			[TO_Y_EVENT] = event(true, { [X_STATE] = transition(to(Y_STATE)) }),
		}
		local stateQ = makeMachine({ events = events })
		local finishedMock = jest.fn()
		stateQ.finished:Connect(finishedMock)

		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(stateQ:getState()).toBe(Y_STATE)
				expect(stateQ:isFinished()).toBe(false)
				expect(finishedMock).never.toHaveBeenCalled()
			end)
		end)

		stateQ:handle(TO_Y_EVENT)
	end, TEST_TIMEOUT_MS)
end)

describe("transition callbacks", function()
	it("use the beforeAsync return value as the next state", function(_, done)
		local stateQ = makeMachine()
		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(stateQ:getState()).toBe(Y_STATE)
			end)
		end)
		stateQ:handle(TO_Y_EVENT)
	end, TEST_TIMEOUT_MS)

	it("run afterAsync after the state has already changed", function(_, done)
		local stateQ
		local stateDuringAfterAsync
		local events = {
			[TO_Y_EVENT] = event(false, {
				[X_STATE] = transition(to(Y_STATE), function()
					stateDuringAfterAsync = stateQ:getState()
				end),
			}),
		}
		stateQ = makeMachine({ events = events })

		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(stateDuringAfterAsync).toBe(Y_STATE)
			end)
		end)

		stateQ:handle(TO_Y_EVENT)
	end, TEST_TIMEOUT_MS)

	it("complete normally when afterAsync is omitted", function(_, done)
		-- standardEvents()'s TO_Y_EVENT has no afterAsync
		local stateQ = makeMachine()
		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(stateQ:getState()).toBe(Y_STATE)
			end)
		end)
		stateQ:handle(TO_Y_EVENT)
	end, TEST_TIMEOUT_MS)
end)

describe("event queue", function()
	it("processes queued events in FIFO order", function(_, done)
		local processedOrder = {}
		local events = {
			[TO_Y_EVENT] = event(false, {
				[X_STATE] = transition(to(Y_STATE), function()
					table.insert(processedOrder, TO_Y_EVENT)
					task.wait()
				end),
			}),
			[TO_X_EVENT] = event(false, {
				[Y_STATE] = transition(to(X_STATE), function()
					table.insert(processedOrder, TO_X_EVENT)
					task.wait()
				end),
			}),
			[FINISH_EVENT] = event(true, {
				[X_STATE] = transition(to(FINISH_STATE), function()
					table.insert(processedOrder, FINISH_EVENT)
				end),
			}),
		}
		local stateQ = makeMachine({ events = events })

		onceSignal(stateQ.finished, function()
			settle(done, function()
				expect(processedOrder).toEqual({ TO_Y_EVENT, TO_X_EVENT, FINISH_EVENT })
			end)
		end)

		stateQ:handle(TO_Y_EVENT)
		stateQ:handle(TO_X_EVENT)
		stateQ:handle(FINISH_EVENT)
	end, TEST_TIMEOUT_MS)

	it("starts the next event only after the previous event's afterEvent", function(_, done)
		local log = {}
		local events = {
			[TO_Y_EVENT] = event(false, { [X_STATE] = transition(to(Y_STATE)) }),
			[TO_X_EVENT] = event(false, {
				[Y_STATE] = transition(function()
					table.insert(log, "secondEvent.beforeAsync")
					return X_STATE
				end),
			}),
		}
		local stateQ = makeMachine({ events = events })
		local afterEventCount = 0

		stateQ.afterEvent:Connect(function(eventName)
			table.insert(log, eventName .. ".afterEvent")
			afterEventCount += 1
			if afterEventCount == 2 then
				settle(done, function()
					local firstAfterEvent = table.find(log, TO_Y_EVENT .. ".afterEvent")
					local secondBeforeAsync = table.find(log, "secondEvent.beforeAsync")
					expect(firstAfterEvent).never.toBeNil()
					expect(secondBeforeAsync).never.toBeNil()
					expect(firstAfterEvent < secondBeforeAsync).toBe(true)
				end)
			end
		end)

		stateQ:handle(TO_Y_EVENT)
		stateQ:handle(TO_X_EVENT)
	end, TEST_TIMEOUT_MS)

	it("processes events enqueued from within a signal handler", function(_, done)
		local events = {
			[TO_Y_EVENT] = event(false, { [X_STATE] = transition(to(Y_STATE)) }),
			[TO_X_EVENT] = event(false, { [Y_STATE] = transition(to(X_STATE)) }),
		}
		local stateQ = makeMachine({ events = events })
		local enqueuedSecond = false

		stateQ.afterEvent:Connect(function(eventName)
			if eventName == TO_Y_EVENT and not enqueuedSecond then
				enqueuedSecond = true
				stateQ:handle(TO_X_EVENT)
			elseif eventName == TO_X_EVENT then
				settle(done, function()
					expect(stateQ:getState()).toBe(X_STATE)
				end)
			end
		end)

		stateQ:handle(TO_Y_EVENT)
	end, TEST_TIMEOUT_MS)
end)

describe("finishing", function()
	it("fires finished and clears state when a final event returns nil", function(_, done)
		local stateQ = makeMachine()
		onceSignal(stateQ.finished, function()
			settle(done, function()
				expect(stateQ:getState()).toBe(FINISH_STATE)
				expect(stateQ:isFinished()).toBe(true)
				expect(stateQ:getValidEvents()).toHaveLength(0)
			end)
		end)
		stateQ:handle(FINISH_EVENT)
	end, TEST_TIMEOUT_MS)

	it("reports an error when an event is handled after finishing", function(_, done)
		local stateQ = makeMachine()
		onceSignal(stateQ.finished, function()
			onceSignal(stateQ.eventErrored, function(errorInfo)
				settle(done, function()
					expect(errorInfo.phase).toBe(PHASE.validation)
					expect(errorInfo.message).toEqual(
						expect.stringContaining(
							`Attempt to process event {FINISH_EVENT} after the state machine already finished`
						)
					)
				end)
			end)
			stateQ:handle(FINISH_EVENT)
		end)
		stateQ:handle(FINISH_EVENT)
	end, TEST_TIMEOUT_MS)
end)

describe("error handling", function()
	it("reports an illegal event for the current state", function(_, done)
		-- TO_X_EVENT is only valid from Y_STATE, but the machine starts in X_STATE
		local stateQ = makeMachine()
		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				expect(errorInfo.phase).toBe(PHASE.validation)
				expect(errorInfo.message).toEqual(
					expect.stringContaining(`Illegal event {TO_X_EVENT} called during state {X_STATE}`)
				)
				expect(errorInfo.eventName).toBe(TO_X_EVENT)
				expect(errorInfo.beforeState).toBe(X_STATE)
			end)
		end)
		stateQ:handle(TO_X_EVENT)
	end, TEST_TIMEOUT_MS)

	it("reports a non-final transition that returns nil", function(_, done)
		local events = {
			[NONFINAL_NIL_EVENT] = event(false, { [X_STATE] = transition(to(FINISH_STATE)) }),
		}
		local stateQ = makeMachine({ events = events })
		local finishedMock = jest.fn()
		stateQ.finished:Connect(finishedMock)

		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				expect(errorInfo.phase).toBe(PHASE.validation)
				expect(errorInfo.message).toEqual(
					expect.stringContaining("did not return next state during a non-final event")
				)
				expect(finishedMock).never.toHaveBeenCalled()
			end)
		end)

		stateQ:handle(NONFINAL_NIL_EVENT)
	end, TEST_TIMEOUT_MS)

	it("reports a transition that returns an invalid state type", function(_, done)
		local events = {
			[BAD_RETURN_EVENT] = event(false, {
				[X_STATE] = transition(function()
					return 123
				end),
			}),
		}
		local stateQ = makeMachine({ events = events })

		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				expect(errorInfo.phase).toBe(PHASE.validation)
			end)
		end)

		stateQ:handle(BAD_RETURN_EVENT)
	end, TEST_TIMEOUT_MS)

	it("reports a beforeAsync that throws", function(_, done)
		local events = {
			[THROW_EVENT] = event(false, { [X_STATE] = transition(throwingHandler("boom in before")) }),
		}
		local stateQ = makeMachine({ events = events })

		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				expect(errorInfo.phase).toBe(PHASE.beforeAsync)
				expect(errorInfo.message).toEqual(expect.stringContaining("boom in before"))
				expect(errorInfo.beforeState).toBe(X_STATE)
			end)
		end)

		stateQ:handle(THROW_EVENT)
	end, TEST_TIMEOUT_MS)

	it("reports an afterAsync that throws", function(_, done)
		local events = {
			[AFTER_THROW_EVENT] = event(false, {
				[X_STATE] = transition(to(Y_STATE), throwingHandler("boom in after")),
			}),
		}
		local stateQ = makeMachine({ events = events })

		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				expect(errorInfo.phase).toBe(PHASE.afterAsync)
				expect(errorInfo.message).toEqual(expect.stringContaining("boom in after"))
				expect(errorInfo.beforeState).toBe(X_STATE)
				expect(errorInfo.afterState).toBe(Y_STATE)
			end)
		end)

		stateQ:handle(AFTER_THROW_EVENT)
	end, TEST_TIMEOUT_MS)

	it("includes the full EventError payload", function(_, done)
		local stateQ = makeMachine({ name = "ShapeMachine" })
		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				expect(errorInfo).toMatchObject({
					machineName = "ShapeMachine",
					eventName = TO_X_EVENT,
					beforeState = X_STATE,
					phase = PHASE.validation,
				})
				expect(errorInfo.message).toEqual(expect.any("string"))
				expect(errorInfo.traceback).toEqual(expect.any("string"))
			end)
		end)
		stateQ:handle(TO_X_EVENT)
	end, TEST_TIMEOUT_MS)

	it("formats an EventError into a single log string", function(_, done)
		local stateQ = makeMachine({ name = "FormatMachine" })
		onceSignal(stateQ.eventErrored, function(errorInfo)
			settle(done, function()
				local formatted = StateQ.formatEventError(errorInfo)
				expect(formatted).toEqual(expect.stringContaining("FormatMachine"))
				expect(formatted).toEqual(expect.stringContaining(TO_X_EVENT))
				expect(formatted).toEqual(expect.stringContaining(errorInfo.phase))
			end)
		end)
		stateQ:handle(TO_X_EVENT)
	end, TEST_TIMEOUT_MS)

	it("exposes the EventErrorPhase enum values", function()
		expect(PHASE.queue).toBe("queue")
		expect(PHASE.validation).toBe("validation")
		expect(PHASE.beforeAsync).toBe("beforeAsync")
		expect(PHASE.afterAsync).toBe("afterAsync")
	end)

	it("re-raises asynchronously when nothing is connected to eventErrored", function(_, done)
		local realSpawn = task.spawn
		local reRaisedMessage
		local spy = jest.spyOn(task, "spawn")
		spy.mockImplementation(function(target, ...)
			-- Intercept only the re-raise (task.spawn(error, message)); pass everything else through
			-- so the queue and signals keep working normally.
			if target == error then
				reRaisedMessage = (select(1, ...))
				return
			end
			return realSpawn(target, ...)
		end)

		local stateQ = makeMachine()
		stateQ:handle(TO_X_EVENT)

		task.delay(0.2, function()
			spy.mockRestore()
			settle(done, function()
				expect(reRaisedMessage).never.toBeNil()
				expect(reRaisedMessage).toEqual(expect.stringContaining(`Illegal event {TO_X_EVENT}`))
			end)
		end)
	end, TEST_TIMEOUT_MS)

	it("does not re-raise when eventErrored has a connection", function(_, done)
		local realSpawn = task.spawn
		local didReRaise = false
		local spy = jest.spyOn(task, "spawn")
		spy.mockImplementation(function(target, ...)
			if target == error then
				didReRaise = true
				return
			end
			return realSpawn(target, ...)
		end)

		local stateQ = makeMachine()
		local receivedError
		stateQ.eventErrored:Connect(function(errorInfo)
			receivedError = errorInfo
		end)
		stateQ:handle(TO_X_EVENT)

		task.delay(0.2, function()
			spy.mockRestore()
			settle(done, function()
				expect(receivedError).never.toBeNil()
				expect(didReRaise).toBe(false)
			end)
		end)
	end, TEST_TIMEOUT_MS)
end)

describe("getState", function()
	it("reflects the current state across transitions", function(_, done)
		local stateQ = makeMachine()
		expect(stateQ:getState()).toBe(X_STATE)
		onceSignal(stateQ.afterEvent, function()
			settle(done, function()
				expect(stateQ:getState()).toBe(Y_STATE)
			end)
		end)
		stateQ:handle(TO_Y_EVENT)
	end, TEST_TIMEOUT_MS)
end)

describe("getValidEvents", function()
	it("returns the valid events for the current state and none when finished", function(_, done)
		local stateQ = makeMachine()
		local validFromX = stateQ:getValidEvents()
		expect(validFromX).toContain(TO_Y_EVENT)
		expect(validFromX).toContain(STAY_X_EVENT)
		expect(validFromX).toContain(FINISH_EVENT)

		onceSignal(stateQ.finished, function()
			settle(done, function()
				expect(stateQ:getValidEvents()).toHaveLength(0)
			end)
		end)
		stateQ:handle(FINISH_EVENT)
	end, TEST_TIMEOUT_MS)
end)

describe("getMaxQueueLength", function()
	it("returns math.huge by default and the configured value when set", function()
		expect(makeMachine():getMaxQueueLength()).toBe(math.huge)
		expect(makeMachine({ maxQueueLength = 7 }):getMaxQueueLength()).toBe(7)
	end)
end)

describe("isFinished and isDestroyed", function()
	it("both start false on a fresh machine", function()
		local stateQ = makeMachine()
		expect(stateQ:isFinished()).toBe(false)
		expect(stateQ:isDestroyed()).toBe(false)
	end)

	it("isFinished flips to true after finishing", function(_, done)
		local stateQ = makeMachine()
		onceSignal(stateQ.finished, function()
			settle(done, function()
				expect(stateQ:isFinished()).toBe(true)
			end)
		end)
		stateQ:handle(FINISH_EVENT)
	end, TEST_TIMEOUT_MS)

	it("isDestroyed flips to true after destroy", function()
		local stateQ = makeMachine()
		stateQ:destroy()
		expect(stateQ:isDestroyed()).toBe(true)
	end)
end)

describe("setDebugEnabled", function()
	it("defaults the debug flag to false", function()
		expect(makeMachine():isDebugEnabled()).toBe(false)
	end)

	it("throws for a non-boolean", function()
		local stateQ = makeMachine()
		for _, badValue in { 1, "bad", {} } do
			expect(function()
				stateQ:setDebugEnabled(badValue)
			end).toThrow(`boolean expected, got {typeof(badValue)}`)
		end
	end)

	it("updates the debug flag", function()
		local stateQ = makeMachine()
		stateQ:setDebugEnabled(true)
		expect(stateQ:isDebugEnabled()).toBe(true)
		stateQ:setDebugEnabled(false)
		expect(stateQ:isDebugEnabled()).toBe(false)
	end)
end)

describe("destroy", function()
	it("marks the machine destroyed and disconnects every signal", function()
		local stateQ = makeMachine()
		for _, signalName in ALL_SIGNALS do
			stateQ[signalName]:Connect(function() end)
		end

		stateQ:destroy()

		expect(stateQ:isDestroyed()).toBe(true)
		for _, signalName in ALL_SIGNALS do
			expect(stateQ[signalName]:hasAnyConnection()).toBe(false)
		end
	end)

	it("rejects further handle calls", function()
		local stateQ = makeMachine()
		stateQ:destroy()
		expect(function()
			stateQ:handle(TO_Y_EVENT)
		end).toThrow("after the state machine was destroyed")
	end)
end)

describe("integration", function()
	it("drives a simple two-state toggle end to end", function(_, done)
		local ON_STATE, OFF_STATE = "On", "Off"
		local SWITCH_ON, SWITCH_OFF = "SwitchOn", "SwitchOff"
		local events = {
			[SWITCH_ON] = event(true, { [OFF_STATE] = transition(to(ON_STATE)) }),
			[SWITCH_OFF] = event(true, { [ON_STATE] = transition(to(OFF_STATE)) }),
		}
		local light = StateQ.new(ON_STATE, events)

		local enteredStates = {}
		light.stateEntered:Connect(function(newState)
			table.insert(enteredStates, newState)
		end)

		local afterEventCount = 0
		light.afterEvent:Connect(function()
			afterEventCount += 1
			if afterEventCount == 2 then
				settle(done, function()
					expect(enteredStates).toEqual({ OFF_STATE, ON_STATE })
					expect(light:getState()).toBe(ON_STATE)
				end)
			end
		end)

		light:handle(SWITCH_OFF)
		light:handle(SWITCH_ON)
	end, TEST_TIMEOUT_MS)

	it("drives a runtime-generated thousand-state chain to completion", function(_, done)
		local chain = generateChainMachine(1000)
		local stateQ = makeMachine({ initialState = chain.initialState, events = chain.events })

		expect(stateQ:getState()).toBe("State1")
		expect(stateQ:getValidEvents()).toContain("Event1")
		expect(stateQ:getMaxQueueLength()).toBe(math.huge)

		onceSignal(stateQ.finished, function(beforeState)
			settle(done, function()
				expect(stateQ:isFinished()).toBe(true)
				expect(stateQ:getState()).toBe(FINISH_STATE)
				expect(beforeState).toBe(`State{chain.eventCount}`)
			end)
		end)

		for i = 1, chain.eventCount do
			stateQ:handle(`Event{i}`)
		end
	end, TEST_TIMEOUT_MS)

	it("aborts remaining processing when destroyed mid-transition", function(_, done)
		local stateQ
		local enteredMock = jest.fn()
		local afterEventMock = jest.fn()
		local finishedMock = jest.fn()
		local events = {
			[FINISH_EVENT] = event(true, {
				[X_STATE] = transition(function()
					-- Yield long enough for the test to destroy the machine mid-transition
					task.wait(0.2)
					return FINISH_STATE
				end),
			}),
		}
		stateQ = makeMachine({ events = events })

		stateQ.stateEntered:Connect(function(...)
			enteredMock(...)
		end)
		stateQ.afterEvent:Connect(function(...)
			afterEventMock(...)
		end)
		stateQ.finished:Connect(function(...)
			finishedMock(...)
		end)

		stateQ:handle(FINISH_EVENT)

		-- Destroy while beforeAsync is still yielding
		task.delay(0.05, function()
			stateQ:destroy()
		end)

		-- After the transition would have completed, assert nothing past beforeAsync ran
		task.delay(0.4, function()
			settle(done, function()
				expect(enteredMock).never.toHaveBeenCalled()
				expect(afterEventMock).never.toHaveBeenCalled()
				expect(finishedMock).never.toHaveBeenCalled()
				expect(stateQ:getState()).toBe(X_STATE)
			end)
		end)
	end, TEST_TIMEOUT_MS)
end)
