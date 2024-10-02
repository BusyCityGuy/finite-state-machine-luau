--!nonstrict
-- FIXME: Change to strict and fix type issues

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local Freeze = require(TestService.Source.DevPackages.Freeze)
local JestGlobals = require(TestService.Source.DevPackages.JestGlobals)
local Logger = require(ReplicatedStorage.Source.Packages.StateQ.Modules.Logger)
local Signal = require(ReplicatedStorage.Source.Packages.StateQ.Modules.Signal)
local StateQ = require(ReplicatedStorage.Source.Packages.StateQ)

-- Shortening things is generally bad practice, but this greatly improves readability of tests
local Dict = Freeze.Dictionary
local it = JestGlobals.it
local expect = JestGlobals.expect
local describe = JestGlobals.describe
local beforeEach = JestGlobals.beforeEach

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

-- local function plural(count: number)
-- 	return if count == 1 then "" else "s"
-- end

-- TODO: Evaluate each test to see if it could be done better in Jest. These are currently just translated directly from TestEZ.
-- Done
describe("new", function()
	describe("should error iff given bad parameter type for", function()
		describe("initial state", function()
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

			local badTypes: { any } = {
				1,
				true,
				nil,
				{},
			}

			local goodType = X_STATE
			for i = 1, #badTypes do
				local badType = badTypes[i]
				it(`{i} bad: {typeof(badType)}`, function()
					expect(function()
						StateQ.new(badType, eventsByName)
					end).toThrow("Bad tuple index #1")
				end)
			end

			it(`good: {typeof(goodType)}`, function()
				expect(function()
					StateQ.new(goodType, eventsByName)
				end).never.toThrow()
			end)
		end)

		describe("events", function()
			local goodEventsByName = {
				[TO_X_EVENT] = {
					canBeFinal = true,
					from = {
						[X_STATE] = {
							beforeAsync = TO_X_HANDLER,
						},
					},
				},
			}

			local badTypes: { any } = {
				1,
				true,
				nil,
				{
					"bad",
					"type",
				},
			}

			for i = 1, #badTypes do
				local badType = badTypes[i]
				it(`{i} bad: {typeof(badType)}`, function()
					expect(function()
						StateQ.new(X_STATE, badType)
					end).toThrow("Bad tuple index #2")
				end)
			end

			it(`good: {typeof(goodEventsByName)}`, function()
				expect(function()
					StateQ.new(X_STATE, goodEventsByName)
				end).never.toThrow()
			end)
		end)

		describe("name", function()
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

			local badTypes: { any } = {
				1,
				true,
				{},
			}

			local goodTypes: { any } = {
				nil,
				"good type",
				"",
			}

			for i = 1, #badTypes do
				local badType = badTypes[i]
				it(`{i} bad: {typeof(badType)}`, function()
					expect(function()
						StateQ.new(X_STATE, eventsByName, badType)
					end).toThrow("Bad tuple index #3")
				end)
			end

			for i = 1, #goodTypes do
				local goodType = goodTypes[i]
				it(`{i} good: {typeof(goodType)}`, function()
					expect(function()
						StateQ.new(X_STATE, eventsByName, goodType)
					end).never.toThrow()
				end)
			end
		end)

		describe("log level", function()
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

			local badTypes: { any } = {
				1,
				true,
				{},
				"bad type",
			}

			local goodTypes: { nil | Logger.LogLevel } = {
				nil,
				StateQ.Logger.LogLevel.Error,
				StateQ.Logger.LogLevel.Warn,
				StateQ.Logger.LogLevel.Info,
				StateQ.Logger.LogLevel.Debug,
			}

			for i = 1, #badTypes do
				local badType = badTypes[i]
				it(`{i} bad: {typeof(badType)}`, function()
					expect(function()
						StateQ.new(X_STATE, eventsByName, nil, badType)
					end).toThrow("Bad tuple index #4")
				end)
			end

			for i = 1, #goodTypes do
				local goodType: nil | Logger.LogLevel = goodTypes[i]
				it(`{i} good: {typeof(goodType)}`, function()
					expect(function()
						StateQ.new(X_STATE, eventsByName, nil, goodType)
					end).never.toThrow()
				end)
			end
		end)
	end)

	it("should return a new unique state machine", function()
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

		local stateQ1 = StateQ.new(initialState, eventsByName)
		local stateQ2 = StateQ.new(initialState, eventsByName)

		expect(stateQ1).toBeInstanceOf(StateQ)
		expect(stateQ2).toBeInstanceOf(StateQ)
		expect(stateQ1 == stateQ2).toBe(false)
	end)

	describe("should initialize", function()
		it("initial state", function()
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

			local stateQ = StateQ.new(initialState, eventsByName)
			expect(stateQ._currentState).toBe(initialState)
		end)

		it("valid event names by state", function()
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

			local stateQ = StateQ.new(X_STATE, eventsByName)
			local validEventNamesFromX = stateQ._validEventNamesByState[X_STATE]
			local validEventNamesFromY = stateQ._validEventNamesByState[Y_STATE]

			expect(validEventNamesFromX).toEqual(expect.any("table"))
			expect(validEventNamesFromY).toEqual(expect.any("table"))

			expect(Dict.count(validEventNamesFromX)).toBe(1)
			expect(Dict.includes(validEventNamesFromX, TO_Y_EVENT)).toBe(true)

			expect(Dict.count(validEventNamesFromY)).toBe(2)
			expect(Dict.includes(validEventNamesFromY, TO_X_EVENT)).toBe(true)
			expect(Dict.includes(validEventNamesFromY, TO_Y_EVENT)).toBe(true)
		end)

		it("handlers by event name", function()
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

			local stateQ = StateQ.new(X_STATE, eventsByName)
			local handlers = stateQ._handlersByEventName

			expect(Dict.count(handlers)).toBe(2)
			expect(handlers[TO_X_EVENT]).toEqual(expect.any("function"))
			expect(handlers[TO_Y_EVENT]).toEqual(expect.any("function"))
		end)

		it("signals", function()
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

			local stateQ = StateQ.new(X_STATE, eventsByName)

			-- FIXME: Can't use toBeInstanceOf because of some weird behavior with ReducedInstance for running tests in lune
			expect(stateQ[BEFORE_EVENT_SIGNAL]).never.toBeNil()
			expect(stateQ[LEAVING_STATE_SIGNAL]).never.toBeNil()
			expect(stateQ[STATE_ENTERED_SIGNAL]).never.toBeNil()
			expect(stateQ[AFTER_EVENT_SIGNAL]).never.toBeNil()
			expect(stateQ[FINISHED_SIGNAL]).never.toBeNil()
		end)
	end)
end)

-- Done
describe("handle", function()
	it("should error iff given a bad event name", function()
		local nonexistentEventName = "nonexistent"
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

		local stateQ = StateQ.new(X_STATE, eventsByName)

		local badTypes: { any } = {
			1,
			true,
			nil,
			{},
		}

		local goodType = TO_X_EVENT

		for _, badType in badTypes do
			expect(function()
				stateQ:handle(badType)
			end).toThrow(`string expected, got {typeof(badType)}`)
		end

		expect(function()
			stateQ:handle(nonexistentEventName)
		end).toThrow(`Invalid event name passed to handle: {nonexistentEventName}`)

		expect(function()
			StateQ.new(goodType, eventsByName)
		end).never.toThrow()
	end)

	describe("should fire signals", function()
		it("in the correct order", function(_, done)
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

			local stateQ = StateQ.new(initialState, eventsByName)
			local resultSignalOrder: { string } = {}
			local signalConnections: { Signal.SignalConnection } = {}

			-- Set up event connections
			for _, signalName in ORDERED_SIGNALS do
				local newSignalConnection = (stateQ[signalName] :: Signal.ClassType):Connect(function(_, _)
					table.insert(resultSignalOrder, signalName)

					if #resultSignalOrder == #ORDERED_SIGNALS then
						for _, signalConnection in signalConnections do
							signalConnection:Disconnect()
						end
						xpcall(function()
							expect(resultSignalOrder).toEqual(ORDERED_SIGNALS)
							done()
						end, function(err)
							done(err)
						end)
					end
				end)

				table.insert(signalConnections, newSignalConnection)
			end

			stateQ:handle(FINISH_EVENT)
		end, 50)

		describe(`with the correct parameters and state`, function()
			local initialState = X_STATE
			local variadicArgs = { "test", false, nil, 3.5 }
			local timeout = 50
			local handledEventName = TO_Y_EVENT
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

			local stateQ

			beforeEach(function()
				receivedParameters = nil
				stateQ = StateQ.new(initialState, eventsByName)
			end)

			it(BEFORE_EVENT_SIGNAL, function(_, done)
				local signalConnection
				signalConnection = stateQ[BEFORE_EVENT_SIGNAL]:Connect(function(...)
					signalConnection:Disconnect()
					receivedParameters = { ... }
					xpcall(function()
						expect(#receivedParameters).toBe(2)
						expect(receivedParameters[1]).toBe(handledEventName)
						expect(receivedParameters[2]).toBe(initialState)
						expect(stateQ._currentState).toBe(initialState)
						done()
					end, function(err)
						done(err)
					end)
				end)

				stateQ:handle(handledEventName, table.unpack(variadicArgs))
			end, timeout)

			it(LEAVING_STATE_SIGNAL, function(_, done)
				local expectedAfterState = Y_STATE

				local signalConnection
				signalConnection = stateQ[LEAVING_STATE_SIGNAL]:Connect(function(...)
					signalConnection:Disconnect()
					receivedParameters = { ... }
					xpcall(function()
						expect(#receivedParameters).toBe(2)
						expect(receivedParameters[1]).toBe(initialState)
						expect(receivedParameters[2]).toBe(expectedAfterState)
						expect(stateQ._currentState).toBe(initialState)
						done()
					end, function(err)
						done(err)
					end)
				end)

				stateQ:handle(handledEventName, table.unpack(variadicArgs))
			end, timeout)

			it(STATE_ENTERED_SIGNAL, function(_, done)
				local expectedAfterState = Y_STATE

				local signalConnection
				signalConnection = stateQ[STATE_ENTERED_SIGNAL]:Connect(function(...)
					signalConnection:Disconnect()
					receivedParameters = { ... }
					xpcall(function()
						expect(#receivedParameters).toBe(2)
						expect(receivedParameters[1]).toBe(expectedAfterState)
						expect(receivedParameters[2]).toBe(initialState)
						expect(stateQ._currentState).toBe(expectedAfterState)
						done()
					end, function(err)
						done(err)
					end)
				end)

				stateQ:handle(handledEventName, table.unpack(variadicArgs))
			end, timeout)

			it(AFTER_EVENT_SIGNAL, function(_, done)
				local expectedAfterState = Y_STATE

				local signalConnection
				signalConnection = stateQ[AFTER_EVENT_SIGNAL]:Connect(function(...)
					signalConnection:Disconnect()
					receivedParameters = { ... }
					xpcall(function()
						expect(#receivedParameters).toBe(3)
						expect(receivedParameters[1]).toBe(handledEventName)
						expect(receivedParameters[2]).toBe(expectedAfterState)
						expect(receivedParameters[3]).toBe(initialState)
						expect(stateQ._currentState).toBe(expectedAfterState)
						done()
					end, function(err)
						done(err)
					end)
				end)

				stateQ:handle(handledEventName, table.unpack(variadicArgs))
			end, timeout)

			it(FINISHED_SIGNAL, function(_, done)
				local signalConnection
				signalConnection = stateQ[FINISHED_SIGNAL]:Connect(function(...)
					signalConnection:Disconnect()
					receivedParameters = { ... }
					xpcall(function()
						expect(#receivedParameters).toBe(1)
						expect(receivedParameters[1]).toBe(initialState)
						expect(stateQ._currentState).toBe(FINISH_STATE)
						done()
					end, function(err)
						done(err)
					end)
				end)

				stateQ:handle(FINISH_EVENT, table.unpack(variadicArgs))
			end, timeout)
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

			local stateQ = StateQ.new(initialState, eventsByName)
			local signalConnections = {}

			stateQ:handle(FINISH_EVENT)

			table.insert(
				signalConnections,
				stateQ[BEFORE_EVENT_SIGNAL]:Connect(function()
					table.insert(firedSignals, BEFORE_EVENT_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateQ[LEAVING_STATE_SIGNAL]:Connect(function()
					table.insert(firedSignals, LEAVING_STATE_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateQ[STATE_ENTERED_SIGNAL]:Connect(function()
					table.insert(firedSignals, STATE_ENTERED_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateQ[AFTER_EVENT_SIGNAL]:Connect(function()
					table.insert(firedSignals, AFTER_EVENT_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateQ[FINISHED_SIGNAL]:Connect(function()
					table.insert(firedSignals, FINISHED_SIGNAL)
				end)
			)

			local timeout = 0.5
			timeoutThreadBefore = task.delay(timeout, function()
				for _, signalConnection in signalConnections do
					signalConnection:Disconnect()
				end
				coroutine.resume(mainThread, `timeout waiting {timeout} seconds for beforeAsync invocation`)
			end)
			local invokedCallback = coroutine.yield()
			expect(invokedCallback).toBe("beforeAsync")
			local expectedFiredSignals = { BEFORE_EVENT_SIGNAL }
			expect(firedSignals[1]).toBe(expectedFiredSignals[1])
			expect(#firedSignals).toBe(#expectedFiredSignals)

			timeoutThreadAfter = task.delay(timeout, function()
				coroutine.resume(mainThread, `timeout waiting {timeout} seconds for afterAsync invocation`)
			end)
			invokedCallback = coroutine.yield()
			for _, signalConnection in signalConnections do
				signalConnection:Disconnect()
			end
			expect(invokedCallback).toBe("afterAsync")
			expectedFiredSignals = {
				BEFORE_EVENT_SIGNAL,
				LEAVING_STATE_SIGNAL,
				STATE_ENTERED_SIGNAL,
			}
			for index, expectedFiredSignal in expectedFiredSignals do
				expect(firedSignals[index]).toBe(expectedFiredSignal)
			end
			expect(#firedSignals).toBe(#expectedFiredSignals)
		end)

		it("with the correct parameters and state", function()
			local initialState = X_STATE
			local variadicArgs = { "test", false, nil, 3.5 }
			local timeout = 0.5
			local timeoutThread
			local mainThread = coroutine.running()
			local handledEventName = FINISH_EVENT
			-- local expectedAfterState = FINISH_STATE
			local receivedParameters
			local stateQ
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

			stateQ = StateQ.new(initialState, eventsByName)

			-- Test beforeAsync
			timeoutThread = task.delay(timeout, function()
				coroutine.resume(mainThread, `timeout waiting {timeout} seconds for beforeAsync invocation`)
			end)

			stateQ:handle(handledEventName, table.unpack(variadicArgs))

			local invokedCallback = coroutine.yield(mainThread)
			expect(invokedCallback).toBe("beforeAsync")
			for index, variadicArg in variadicArgs do
				expect(receivedParameters[index]).toBe(variadicArg)
			end
			expect(#receivedParameters).toBe(#variadicArgs)
			expect(stateQ._currentState).toBe(initialState)

			-- Test afterAsync
			timeoutThread = task.delay(timeout, function()
				coroutine.resume(mainThread, `timeout waiting {timeout} seconds for afterAsync invocation`)
			end)

			-- local invokedCallback = coroutine.yield(mainThread)
			-- expect(invokedCallback).toBe("afterAsync")
			-- for index, variadicArg in variadicArgs do
			-- 	expect(receivedParameters[index]).toBe(variadicArg)
			-- end
			-- expect(#receivedParameters).toBe(#variadicArgs)
			-- expect(stateQ._currentState).toBe(expectedAfterState)
		end)
	end)

	it("should queue and process async events in FIFO order", function()
		local initialState = X_STATE
		local timeout = 0.5
		local mainThread = coroutine.running()
		local orderedHandledEvents = {
			TO_Y_EVENT,
			TO_X_EVENT,
			FINISH_EVENT,
		}
		local actualHandledEvents = {}
		local eventsByName = {
			[TO_Y_EVENT] = {
				canBeFinal = false,
				from = {
					[X_STATE] = {
						beforeAsync = TO_Y_HANDLER,
						afterAsync = function()
							table.insert(actualHandledEvents, TO_Y_EVENT)
							task.wait()
						end,
					},
				},
			},
			[TO_X_EVENT] = {
				canBeFinal = false,
				from = {
					[Y_STATE] = {
						beforeAsync = TO_X_HANDLER,
						afterAsync = function()
							table.insert(actualHandledEvents, TO_X_EVENT)
							task.wait()
						end,
					},
				},
			},
			[FINISH_EVENT] = {
				canBeFinal = true,
				from = {
					[X_STATE] = {
						beforeAsync = FINISH_HANDLER,
						afterAsync = function()
							table.insert(actualHandledEvents, FINISH_EVENT)
							task.wait()
						end,
					},
				},
			},
		}

		local stateQ = StateQ.new(initialState, eventsByName)

		-- Queue events
		for _, handledEventName in ipairs(orderedHandledEvents) do
			stateQ:handle(handledEventName)
		end

		local timeoutThread = task.delay(timeout, function()
			coroutine.resume(mainThread, `timeout waiting {timeout} seconds for finished signal`)
		end)

		local signalConnection = stateQ[FINISHED_SIGNAL]:Connect(function()
			task.cancel(timeoutThread)
			coroutine.resume(mainThread, FINISHED_SIGNAL)
		end)

		local invokedCallback = coroutine.yield(mainThread)
		signalConnection:Disconnect()
		expect(invokedCallback).toBe(FINISHED_SIGNAL)
		for index, expectedHandledEventName in orderedHandledEvents do
			expect(actualHandledEvents[index]).toBe(expectedHandledEventName)
		end
		expect(#actualHandledEvents).toBe(#orderedHandledEvents)
	end)

	it("should error if called after the machine finished", function()
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

		local stateQ = StateQ.new(X_STATE, eventsByName)
		local mainThread = coroutine.running()
		local logger = stateQ:getLogger()

		local timeout = 0.5
		local timeoutMessage = `timeout waiting {timeout} seconds for finished or error message`
		local timeoutThread = task.delay(timeout, function()
			coroutine.resume(mainThread, timeoutMessage)
		end)

		stateQ:handle(FINISH_EVENT)
		stateQ.finished:Wait()
		expect(stateQ._currentState).toBe(FINISH_STATE)

		logger:addHandler(logger.LogLevel.Error, function(level: Logger.LogLevel, _name: string, message: string)
			if level ~= logger.LogLevel.Error then
				return
			end

			if coroutine.status(timeoutThread) ~= "suspended" then
				return
			end

			task.cancel(timeoutThread)
			coroutine.resume(mainThread, message)
			return logger.HandlerResult.Sink
		end)

		stateQ:handle(FINISH_EVENT)
		local errorMessage = coroutine.yield()
		expect(errorMessage == timeoutMessage).never.toBe(true)
		expect(errorMessage).toEqual(
			expect.stringContaining(`Attempt to process event {FINISH_EVENT} after the state machine already finished`)
		)
	end, 50)
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

-- 		local stateQ = StateQ.new(initialState, eventsByName)

-- 		-- Test getting the current state
-- 		local state = stateQ:getState()
-- 		expect(state).toBe(initialState)

-- 		-- Test getting the state after a transition
-- 		stateQ:handle("toB")
-- 		state = stateQ:getState()
-- 		expect(state).toBe("B")
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

-- 		local stateQ = StateQ.new(initialState, eventsByName)

-- 		-- Test getting valid events for the initial state
-- 		local validEvents = stateQ:getValidEvents()
-- 		expect(#validEvents).toBe(1)
-- 		expect(validEvents[1]).toBe("toB")

-- 		-- Test getting valid events after a transition
-- 		stateQ:handle("toB")
-- 		validEvents = stateQ:getValidEvents()
-- 		expect(#validEvents).toBe(1)
-- 		expect(validEvents[1]).toBe("toA")
-- 	end)
-- end)

-- Done
-- describe("_isDebugEnabled", function()
-- 	it("should default to false", function()
-- 		local eventsByName = {
-- 			[TO_X_EVENT] = {
-- 				canBeFinal = true,
-- 				from = {
-- 					[X_STATE] = {
-- 						beforeAsync = TO_X_HANDLER,
-- 					},
-- 				},
-- 			},
-- 		}

-- 		local stateQ = StateQ.new(X_STATE, eventsByName)
-- 		expect(stateQ._isDebugEnabled).toBe(false)
-- 	end)

-- 	describe("setter", function()
-- 		it("should error given a bad type", function()
-- 			local eventsByName = {
-- 				[TO_X_EVENT] = {
-- 					canBeFinal = true,
-- 					from = {
-- 						[X_STATE] = {
-- 							beforeAsync = TO_X_HANDLER,
-- 						},
-- 					},
-- 				},
-- 			}

-- 			local stateQ = StateQ.new(X_STATE, eventsByName)

-- 			local badTypes = {
-- 				1,
-- 				"bad",
-- 				nil,
-- 				{},
-- 			}

-- 			for _, badType in badTypes do
-- 				expect(function()
-- 					stateQ:setDebugEnabled(badType)
-- 				end).toThrow(`boolean expected, got {typeof(badType)}`)
-- 			end
-- 		end)

-- 		it("should set the value correctly", function()
-- 			local eventsByName = {
-- 				[TO_X_EVENT] = {
-- 					canBeFinal = true,
-- 					from = {
-- 						[X_STATE] = {
-- 							beforeAsync = TO_X_HANDLER,
-- 						},
-- 					},
-- 				},
-- 			}

-- 			local stateQ = StateQ.new(X_STATE, eventsByName)

-- 			stateQ:setDebugEnabled(true)
-- 			expect(stateQ._isDebugEnabled).toBe(true)

-- 			stateQ:setDebugEnabled(false)
-- 			expect(stateQ._isDebugEnabled).toBe(false)
-- 		end)
-- 	end)
-- end)

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

-- 		local stateQ = StateQ.new(initialState, eventsByName)

-- 		-- Test destroying the state machine
-- 		stateQ:destroy()
-- 		expect(stateQ._isDestroyed).toBe(true)
-- 		expect(stateQ[BEFORE_EVENT_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateQ[LEAVING_STATE_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateQ[STATE_ENTERED_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateQ[AFTER_EVENT_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateQ[FINISHED_SIGNAL]:getConnectionCount()).toBe(0)
-- 	end)
-- end)

-- return function()
-- 	local StateQ = require(script.Parent.Parent.StateQ)

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

-- 		local machine = StateQ.new("A", states)
-- 		machine:setDebugEnabled(true)
-- 		return machine
-- 	end

-- 	describe("new", function()
-- 		it("should create a new StateQ", function()
-- 			local machine = createTestMachine()
-- 			expect(machine).never.toBeNil()
-- 		end)

-- 		it("should require an initial state", function()
-- 			expect(function()
-- 				StateQ.new()
-- 			end).toThrow()
-- 		end)

-- 		it("should require events", function()
-- 			expect(function()
-- 				StateQ.new("A")
-- 			end).toThrow()
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

-- 			expect(events).never.toBeNil()
-- 			expect(events[1]).toBe("B")
-- end
