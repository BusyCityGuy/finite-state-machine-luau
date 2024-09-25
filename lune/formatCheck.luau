--!strict

--[[
	Checks the format for all the same paths that get checked in the CI pipeline.
	This is just a check that prints problems to the output.
	To fix the format, run `lune run formatFix` instead.

	Since the parent folder is named `lune`, the `lune` cli will automatically look in this directory for scripts to run.

	Usage (from project directory):
		lune run formatCheck
--]]

local Path = require("Utils/Path")
local process = require("@lune/process")
local runShellScript = require("Utils/runShellScript")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local FORMAT_PATHS = {
	Path.join("src", "StateQ"),
	Path.join("src", "TestService"),
	"lune",
}

local NUM_EXPECTED_TASKS = #FORMAT_PATHS

local numErrors = 0
local numTasksCompleted = 0
local mainThread = coroutine.running()

local function checkFormatForPath(path: string)
	local formatCheckScriptPath = Path.join(".", "scripts", "formatCheck.sh")
	local proc = runShellScript(formatCheckScriptPath, { path })

	print(proc.stdout)
	if not proc.ok then
		stdio.ewrite(tostring(proc.stderr))
		numErrors += 1
	end

	numTasksCompleted += 1
	if numTasksCompleted == NUM_EXPECTED_TASKS then
		coroutine.resume(mainThread)
	end
end

local function formatCheckAllPaths()
	print(`Checking format for {NUM_EXPECTED_TASKS} paths:`)
	for _, path in ipairs(FORMAT_PATHS) do
		task.spawn(checkFormatForPath, path)
	end

	if numTasksCompleted < NUM_EXPECTED_TASKS then
		coroutine.yield()
	end

	if numErrors > 0 then
		stdio.ewrite(`{numErrors} of {NUM_EXPECTED_TASKS} paths FAILED formatting checks\n`)
		process.exit(1)
	end

	stdio.write(`All ({NUM_EXPECTED_TASKS}) paths passed format checks successfully\n`)
end

formatCheckAllPaths()
