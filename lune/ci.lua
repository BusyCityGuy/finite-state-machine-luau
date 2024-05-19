--!strict

--[[
	Runs all the same checks that CI steps run, including analysis, format check, linting, and testing.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run ci
--]]

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local LUNE_COMMANDS = {
	"lint",
	"formatCheck",
	"analyze",
	"test",
}

local NUM_EXPECTED_TASKS = #LUNE_COMMANDS

local numErrors = 0
local numTasksCompleted = 0
local mainThread = coroutine.running()

local function runLuneCommand(command: string)
	local home = process.env.HOME
	local proc = process.spawn(`{home}/.aftman/bin/lune`, { "run", command })
	print(proc.stdout)
	if not proc.ok then
		stdio.ewrite(proc.stderr)
		numErrors += 1
	end

	numTasksCompleted += 1
	if numTasksCompleted == NUM_EXPECTED_TASKS then
		coroutine.resume(mainThread)
	end
end

local function runAllLuneCommands()
	print(`Fixing format for {NUM_EXPECTED_TASKS} paths:`)
	for _, path in ipairs(LUNE_COMMANDS) do
		task.spawn(runLuneCommand, path)
	end

	if numTasksCompleted < NUM_EXPECTED_TASKS then
		coroutine.yield()
	end

	if numErrors > 0 then
		stdio.ewrite(`{numErrors} of {NUM_EXPECTED_TASKS} commands FAILED\n`)
		process.exit(1)
	end

	stdio.write(`All ({NUM_EXPECTED_TASKS}) commands succeeded\n`)
end

runAllLuneCommands()
