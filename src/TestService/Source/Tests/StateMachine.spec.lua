--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

local JestGlobals = require(TestService.Dependencies.JestGlobals)
local Freeze = require(TestService.Dependencies.Freeze)
local Logger = require(ReplicatedStorage.Source.StateMachine.Modules.Logger)
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

describe("test", function()
	it("should pass", function()
		expect(true).toBe(true)
	end)
end)
