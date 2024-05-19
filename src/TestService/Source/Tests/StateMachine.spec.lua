--!nonstrict
-- FIXME: Change to strict and fix type issues

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local Freeze = require(TestService.Dependencies.Freeze)
local JestGlobals = require(TestService.Dependencies.JestGlobals)
local Logger = require(ReplicatedStorage.Source.StateMachine.Modules.Logger)
local Signal = require(ReplicatedStorage.Source.StateMachine.Modules.Signal)
local StateMachine = require(ReplicatedStorage.Source.StateMachine)

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
		it("initial state", function()
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

			for _, badType in badTypes do
				expect(function()
					StateMachine.new(badType, eventsByName)
				end).toThrow("Bad tuple index #1")
			end

			expect(function()
				StateMachine.new(goodType, eventsByName)
			end).never.toThrow()
		end)

		it("events", function()
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

			for _, badType in badTypes do
				expect(function()
					StateMachine.new(X_STATE, badType)
				end).toThrow("Bad tuple index #2")
			end

			expect(function()
				StateMachine.new(X_STATE, goodEventsByName)
			end).never.toThrow()
		end)

		it("name", function()
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

			local goodTypes: { any } = {
				nil,
				"good type",
				"",
			}

			for _, badType in badTypes do
				expect(function()
					StateMachine.new(X_STATE, eventsByName, badType)
				end).toThrow("Bad tuple index #3")
			end

			for _, goodType in goodTypes do
				expect(function()
					StateMachine.new(X_STATE, eventsByName, goodType)
				end).never.toThrow()
			end
		end)

		it("log level", function()
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
				"bad type",
			}

			local goodTypes: { nil | Logger.LogLevel } = {
				nil,
				StateMachine.Logger.LogLevel.Error,
				StateMachine.Logger.LogLevel.Warn,
				StateMachine.Logger.LogLevel.Info,
				StateMachine.Logger.LogLevel.Debug,
			}

			for _, badType in badTypes do
				expect(function()
					StateMachine.new(X_STATE, eventsByName, nil, badType)
				end).toThrow("Bad tuple index #4")
			end

			for _, goodType: nil | Logger.LogLevel in goodTypes do
				expect(function()
					StateMachine.new(X_STATE, eventsByName, nil, goodType)
				end).never.toThrow()
			end
		end)
	end)

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

		expect(stateMachine1).toBeInstanceOf(StateMachine)
		expect(stateMachine2).toBeInstanceOf(StateMachine)
		expect(stateMachine1 == stateMachine2).toBe(false)
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
		expect(stateMachine._currentState).toBe(initialState)
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

		expect(validEventNamesFromX).toEqual(expect.any("table"))
		expect(validEventNamesFromY).toEqual(expect.any("table"))

		expect(Dict.count(validEventNamesFromX)).toBe(1)
		expect(Dict.includes(validEventNamesFromX, TO_Y_EVENT)).toBe(true)

		expect(Dict.count(validEventNamesFromY)).toBe(2)
		expect(Dict.includes(validEventNamesFromY, TO_X_EVENT)).toBe(true)
		expect(Dict.includes(validEventNamesFromY, TO_Y_EVENT)).toBe(true)
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

		expect(Dict.count(handlers)).toBe(2)
		expect(handlers[TO_X_EVENT]).toEqual(expect.any("function"))
		expect(handlers[TO_Y_EVENT]).toEqual(expect.any("function"))
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

		expect(stateMachine[BEFORE_EVENT_SIGNAL]).never.toBeNil()
		expect(stateMachine[LEAVING_STATE_SIGNAL]).never.toBeNil()
		expect(stateMachine[STATE_ENTERED_SIGNAL]).never.toBeNil()
		expect(stateMachine[AFTER_EVENT_SIGNAL]).never.toBeNil()
		expect(stateMachine[FINISHED_SIGNAL]).never.toBeNil()
	end)
end)

-- Done
describe("handle", function()
	it("should error given a bad event name", function()
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

		local stateMachine = StateMachine.new(X_STATE, eventsByName)

		local badTypes: { any } = {
			1,
			true,
			nil,
			{},
		}

		for _, badType in badTypes do
			expect(function()
				stateMachine:handle(badType)
			end).toThrow(`string expected, got {typeof(badType)}`)
		end

		expect(function()
			stateMachine:handle(nonexistentEventName)
		end).toThrow(`Invalid event name passed to handle: {nonexistentEventName}`)
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

			local stateMachine = StateMachine.new(initialState, eventsByName)
			local resultSignalOrder: { string } = {}
			local signalConnections: { Signal.SignalConnection } = {}

			-- Set up event connections
			for _, signalName in ORDERED_SIGNALS do
				local newSignalConnection = (stateMachine[signalName] :: Signal.ClassType):Connect(function(_, _)
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

			stateMachine:handle(FINISH_EVENT)
		end, 500)

		describe(`with the correct parameters and state`, function()
			local initialState = X_STATE
			local variadicArgs = { "test", false, nil, 3.5 }
			local timeout = 0.5
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

				local signalConnection = stateMachine[BEFORE_EVENT_SIGNAL]:Connect(function(...)
					receivedParameters = { ... }
					task.cancel(timeoutThread)
					coroutine.resume(mainThread, false)
				end)

				stateMachine:handle(handledEventName, table.unpack(variadicArgs))

				local didTimeOut = coroutine.yield(mainThread)
				signalConnection:Disconnect()
				expect(didTimeOut).toBe(false)
				expect(#receivedParameters).toBe(2)
				expect(receivedParameters[1]).toBe(handledEventName)
				expect(receivedParameters[2]).toBe(initialState)
				expect(stateMachine._currentState).toBe(initialState)
			end)

			it(LEAVING_STATE_SIGNAL, function()
				local expectedAfterState = Y_STATE
				local mainThread = coroutine.running()
				local timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, true)
				end)

				local signalConnection = stateMachine[LEAVING_STATE_SIGNAL]:Connect(function(...)
					receivedParameters = { ... }
					task.cancel(timeoutThread)
					coroutine.resume(mainThread, false)
				end)

				stateMachine:handle(handledEventName, table.unpack(variadicArgs))

				local didTimeOut = coroutine.yield(mainThread)
				signalConnection:Disconnect()
				expect(didTimeOut).toBe(false)
				expect(#receivedParameters).toBe(2)
				expect(receivedParameters[1]).toBe(initialState)
				expect(receivedParameters[2]).toBe(expectedAfterState)
				expect(stateMachine._currentState).toBe(initialState)
			end)

			it(STATE_ENTERED_SIGNAL, function()
				local expectedAfterState = Y_STATE
				local mainThread = coroutine.running()
				local timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, true)
				end)

				local signalConnection = stateMachine[STATE_ENTERED_SIGNAL]:Connect(function(...)
					receivedParameters = { ... }
					task.cancel(timeoutThread)
					coroutine.resume(mainThread, false)
				end)

				stateMachine:handle(handledEventName, table.unpack(variadicArgs))

				local didTimeOut = coroutine.yield(mainThread)
				signalConnection:Disconnect()
				expect(didTimeOut).toBe(false)
				expect(#receivedParameters).toBe(2)
				expect(receivedParameters[1]).toBe(expectedAfterState)
				expect(receivedParameters[2]).toBe(initialState)
				expect(stateMachine._currentState).toBe(expectedAfterState)
			end)

			it(AFTER_EVENT_SIGNAL, function()
				local expectedAfterState = Y_STATE
				local mainThread = coroutine.running()
				local timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, true)
				end)

				local signalConnection = stateMachine[AFTER_EVENT_SIGNAL]:Connect(function(...)
					receivedParameters = { ... }
					task.cancel(timeoutThread)
					coroutine.resume(mainThread, false)
				end)

				stateMachine:handle(handledEventName, table.unpack(variadicArgs))

				local didTimeOut = coroutine.yield(mainThread)
				signalConnection:Disconnect()
				expect(didTimeOut).toBe(false)
				expect(#receivedParameters).toBe(3)
				expect(receivedParameters[1]).toBe(handledEventName)
				expect(receivedParameters[2]).toBe(expectedAfterState)
				expect(receivedParameters[3]).toBe(initialState)
				expect(stateMachine._currentState).toBe(expectedAfterState)
			end)

			it(FINISHED_SIGNAL, function()
				local mainThread = coroutine.running()
				local timeoutThread = task.delay(timeout, function()
					coroutine.resume(mainThread, true)
				end)

				local signalConnection = stateMachine[FINISHED_SIGNAL]:Connect(function(...)
					receivedParameters = { ... }
					task.cancel(timeoutThread)
					coroutine.resume(mainThread, false)
				end)

				stateMachine:handle(FINISH_EVENT, table.unpack(variadicArgs))

				local didTimeOut = coroutine.yield(mainThread)
				signalConnection:Disconnect()
				expect(didTimeOut).toBe(false)
				expect(#receivedParameters).toBe(1)
				expect(receivedParameters[1]).toBe(initialState)
				expect(stateMachine._currentState).toBe(FINISH_STATE)
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
			local signalConnections = {}

			stateMachine:handle(FINISH_EVENT)

			table.insert(
				signalConnections,
				stateMachine[BEFORE_EVENT_SIGNAL]:Connect(function()
					table.insert(firedSignals, BEFORE_EVENT_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateMachine[LEAVING_STATE_SIGNAL]:Connect(function()
					table.insert(firedSignals, LEAVING_STATE_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateMachine[STATE_ENTERED_SIGNAL]:Connect(function()
					table.insert(firedSignals, STATE_ENTERED_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateMachine[AFTER_EVENT_SIGNAL]:Connect(function()
					table.insert(firedSignals, AFTER_EVENT_SIGNAL)
				end)
			)

			table.insert(
				signalConnections,
				stateMachine[FINISHED_SIGNAL]:Connect(function()
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
			expect(invokedCallback).toBe("beforeAsync")
			for index, variadicArg in variadicArgs do
				expect(receivedParameters[index]).toBe(variadicArg)
			end
			expect(#receivedParameters).toBe(#variadicArgs)
			expect(stateMachine._currentState).toBe(initialState)

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
			-- expect(stateMachine._currentState).toBe(expectedAfterState)
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

		local stateMachine = StateMachine.new(initialState, eventsByName)

		-- Queue events
		for _, handledEventName in ipairs(orderedHandledEvents) do
			stateMachine:handle(handledEventName)
		end

		local timeoutThread = task.delay(timeout, function()
			coroutine.resume(mainThread, `timeout waiting {timeout} seconds for finished signal`)
		end)

		local signalConnection = stateMachine[FINISHED_SIGNAL]:Connect(function()
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

		local stateMachine = StateMachine.new(X_STATE, eventsByName)
		local mainThread = coroutine.running()
		local logger = stateMachine:getLogger()

		local timeout = 0.5
		local timeoutMessage = `timeout waiting {timeout} seconds for finished or error message`
		local timeoutThread = task.delay(timeout, function()
			coroutine.resume(mainThread, timeoutMessage)
		end)

		stateMachine:handle(FINISH_EVENT)
		stateMachine.finished:Wait()
		expect(stateMachine._currentState).toBe(FINISH_STATE)

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

		stateMachine:handle(FINISH_EVENT)
		local errorMessage = coroutine.yield()
		expect(errorMessage == timeoutMessage).never.toBe(true)
		expect(errorMessage).toEqual(
			expect.stringContaining(`Attempt to process event {FINISH_EVENT} after the state machine already finished`)
		)
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
-- 		expect(state).toBe(initialState)

-- 		-- Test getting the state after a transition
-- 		stateMachine:handle("toB")
-- 		state = stateMachine:getState()
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

-- 		local stateMachine = StateMachine.new(initialState, eventsByName)

-- 		-- Test getting valid events for the initial state
-- 		local validEvents = stateMachine:getValidEvents()
-- 		expect(#validEvents).toBe(1)
-- 		expect(validEvents[1]).toBe("toB")

-- 		-- Test getting valid events after a transition
-- 		stateMachine:handle("toB")
-- 		validEvents = stateMachine:getValidEvents()
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

-- 		local stateMachine = StateMachine.new(X_STATE, eventsByName)
-- 		expect(stateMachine._isDebugEnabled).toBe(false)
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

-- 			local stateMachine = StateMachine.new(X_STATE, eventsByName)

-- 			local badTypes = {
-- 				1,
-- 				"bad",
-- 				nil,
-- 				{},
-- 			}

-- 			for _, badType in badTypes do
-- 				expect(function()
-- 					stateMachine:setDebugEnabled(badType)
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

-- 			local stateMachine = StateMachine.new(X_STATE, eventsByName)

-- 			stateMachine:setDebugEnabled(true)
-- 			expect(stateMachine._isDebugEnabled).toBe(true)

-- 			stateMachine:setDebugEnabled(false)
-- 			expect(stateMachine._isDebugEnabled).toBe(false)
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

-- 		local stateMachine = StateMachine.new(initialState, eventsByName)

-- 		-- Test destroying the state machine
-- 		stateMachine:destroy()
-- 		expect(stateMachine._isDestroyed).toBe(true)
-- 		expect(stateMachine[BEFORE_EVENT_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateMachine[LEAVING_STATE_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateMachine[STATE_ENTERED_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateMachine[AFTER_EVENT_SIGNAL]:getConnectionCount()).toBe(0)
-- 		expect(stateMachine[FINISHED_SIGNAL]:getConnectionCount()).toBe(0)
-- 	end)
-- end)

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
-- 			expect(machine).never.toBeNil()
-- 		end)

-- 		it("should require an initial state", function()
-- 			expect(function()
-- 				StateMachine.new()
-- 			end).toThrow()
-- 		end)

-- 		it("should require events", function()
-- 			expect(function()
-- 				StateMachine.new("A")
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
